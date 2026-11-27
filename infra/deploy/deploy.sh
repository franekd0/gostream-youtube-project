#!/bin/sh
set -eu

valid_tag() {
    case "$1" in
        ''|*[!0-9a-f]*) return 1 ;;
    esac
    [ "${#1}" -eq 40 ]
}

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <40-character Git commit SHA>" >&2
    exit 2
fi
new_tag=$1
if ! valid_tag "$new_tag"; then
    echo "Expected a 40-character lowercase Git commit SHA" >&2
    exit 2
fi
IMAGE_TAG=$new_tag
export IMAGE_TAG

umask 077
state_dir="${JENKINS_AGENT_WORKDIR:-/home/jenkins/agent}/deploy-state"
state_file="$state_dir/last-good-tag"
mkdir -p "$state_dir"
pending_state=$(mktemp "$state_dir/.last-good-tag.XXXXXX")
trap 'rm -f "$pending_state"' EXIT

cd "$(dirname "$0")/../.."

compose() {
    docker compose -f compose.deploy.yaml "$@"
}

check_application() {
    # Run inside the frontend so this also works from a containerized deploy agent.
    compose exec -T frontend wget -T 10 -qO- http://127.0.0.1/api/health
}

running_tag() {
    service=$1
    container=$(compose ps -q "$service") && [ -n "$container" ] || return 1
    image=$(docker inspect --format '{{.Config.Image}}' "$container") || return 1
    image_prefix="127.0.0.1:8081/gostream/gostream-$service:"
    case "$image" in
        "$image_prefix"*) tag=${image#"$image_prefix"} ;;
        *) return 1 ;;
    esac
    valid_tag "$tag" && printf '%s\n' "$tag"
}

save_tag() {
    printf '%s\n' "$1" > "$pending_state" && mv -f "$pending_state" "$state_file"
}

last_good_tag=
if [ -f "$state_file" ]; then
    last_good_tag=$(cat "$state_file")
    if ! valid_tag "$last_good_tag"; then
        echo "Invalid rollback tag in $state_file" >&2
        exit 1
    fi
elif backend_tag=$(running_tag backend) &&
    frontend_tag=$(running_tag frontend) &&
    [ "$backend_tag" = "$frontend_tag" ] &&
    check_application >/dev/null
then
    last_good_tag=$backend_tag
    save_tag "$last_good_tag"
    # save_tag moves the temporary file, so prepare a fresh one for the new tag.
    pending_state=$(mktemp "$state_dir/.last-good-tag.XXXXXX")
    printf 'Recorded running version %s for rollback.\n' "$last_good_tag"
fi

printf 'Pulling images for %s.\n' "$new_tag"
compose pull
if compose up -d --pull never --wait --wait-timeout 90 &&
    check_application &&
    save_tag "$new_tag"
then
    printf '\nDeployment of %s succeeded.\n' "$new_tag"
    exit 0
fi

printf '\nDeployment of %s failed.\n' "$new_tag" >&2
if [ -z "$last_good_tag" ]; then
    echo 'Rollback unavailable because no working version has been recorded.' >&2
    exit 1
fi

printf 'Restoring %s.\n' "$last_good_tag" >&2
IMAGE_TAG=$last_good_tag
if compose up -d --pull missing --wait --wait-timeout 90 && check_application; then
    printf '\nRollback to %s succeeded.\n' "$last_good_tag" >&2
else
    printf '\nRollback to %s failed.\n' "$last_good_tag" >&2
fi
exit 1
