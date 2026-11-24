#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: ./infra/helpers/ci.sh
       ./infra/helpers/ci.sh {jenkins|nexus} [local-port] [remote-port]

Open a single SSH connection through galera for Jenkins (8080) and Nexus (8081).
Specify a service to forward only its port.
EOF
}

open_tunnel() {
  local port
  for port in "$@"; do
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

  local -a forwards=()
  local local_port remote_port
  printf 'Once SSH connects, open the following URLs. Press Ctrl+C to close the tunnel.\n'
  while (( $# > 0 )); do
    local_port=$1 remote_port=$2
    shift 2
    printf '  http://127.0.0.1:%s\n' "$local_port"
    forwards+=(-L "127.0.0.1:${local_port}:127.0.0.1:${remote_port}")
  done

  exec ssh -N -S none -o ExitOnForwardFailure=yes \
    -J "${JENKINS_SSH_USER}@galera.ii.pw.edu.pl" \
    "${forwards[@]}" \
    "${JENKINS_SSH_USER}@pis07.ii.pw.edu.pl"
}

open_service_tunnel() {
  local default_port=$1
  shift
  if (( $# > 2 )); then
    usage >&2
    return 2
  fi
  open_tunnel "${1-$default_port}" "${2-$default_port}"
}

if (( $# == 0 )); then
  open_tunnel 8080 8080 8081 8081
fi

case $1 in
  jenkins)
    shift
    open_service_tunnel 8080 "$@"
    ;;
  nexus)
    shift
    open_service_tunnel 8081 "$@"
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
