#!/bin/sh
set -eu

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <40-character Git commit SHA>" >&2
    exit 2
fi
IMAGE_TAG=$1
case "$IMAGE_TAG" in
    ''|*[!0-9a-f]*) echo "Expected a lowercase Git commit SHA" >&2; exit 2 ;;
esac
if [ "${#IMAGE_TAG}" -ne 40 ]; then
    echo "Expected a 40-character Git commit SHA" >&2
    exit 2
fi
export IMAGE_TAG

cd "$(dirname "$0")/../.."
docker compose -f compose.deploy.yaml pull
docker compose -f compose.deploy.yaml up -d --pull never --wait --wait-timeout 90

# Run inside the frontend so this also works from a containerized deploy agent.
docker compose -f compose.deploy.yaml exec -T frontend wget -qO- http://127.0.0.1/api/hello
