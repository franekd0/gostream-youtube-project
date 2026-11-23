#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: ./infra/helpers/ci.sh jenkins [local-port] [remote-port]

Open a local SSH tunnel to Jenkins through galera. Both ports default to 8080.
EOF
}

jenkins() {
  if (( $# > 2 )); then
    usage >&2
    return 2
  fi

  local local_port=${1-8080} remote_port=${2-8080} port
  for port in "$local_port" "$remote_port"; do
    if [[ ! $port =~ ^[1-9][0-9]{0,4}$ ]] || (( port > 65535 )); then
      printf 'Invalid port %q. Use a port from 1 to 65535.\n' "$port" >&2
      return 2
    fi
  done

  local project_dir
  project_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
  if [[ -f $project_dir/.env ]]; then
    source "$project_dir/.env"
  fi
  if [[ -z ${JENKINS_SSH_USER:-} ]]; then
    printf 'Set JENKINS_SSH_USER in .env. Use .env.example as a template.\n' >&2
    return 1
  fi

  printf 'Once SSH connects, open http://127.0.0.1:%s. Press Ctrl+C to close the tunnel.\n' "$local_port"
  exec ssh -N -S none -o ExitOnForwardFailure=yes \
    -J "${JENKINS_SSH_USER}@galera.ii.pw.edu.pl" \
    -L "127.0.0.1:${local_port}:127.0.0.1:${remote_port}" \
    "${JENKINS_SSH_USER}@pis07.ii.pw.edu.pl"
}

case ${1:-help} in
  jenkins)
    shift
    jenkins "$@"
    ;;
  help|-h|--help)
    usage
    ;;
  *)
    printf 'Unknown command %q.\n' "$1" >&2
    usage >&2
    exit 2
    ;;
esac
