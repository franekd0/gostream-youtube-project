#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: ./infra/helpers/ci.sh
       ./infra/helpers/ci.sh {jenkins|nexus|grafana|prometheus|sonarqube|app} [local-port] [remote-port]

Open one SSH connection through galera for Jenkins (8080), Nexus (8081),
Grafana (3001), Prometheus (9090), SonarQube (9000), and GoStream (3000).
Specify a service to forward only its port.
EOF
}

open_tunnel() {
  local -a forwards=() urls=()
  local service local_port remote_port port
  while (( $# > 0 )); do
    service=$1 local_port=$2 remote_port=$3
    shift 3
    for port in "$local_port" "$remote_port"; do
      if [[ ! $port =~ ^[1-9][0-9]{0,4}$ ]] || (( port > 65535 )); then
        printf 'Invalid port %q. Use a port from 1 to 65535.\n' "$port" >&2
        return 2
      fi
    done
    urls+=("http://127.0.0.1:$local_port : $service")
    forwards+=(-L "127.0.0.1:${local_port}:127.0.0.1:${remote_port}")
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

  printf 'Once SSH connects, open the following URLs. Press Ctrl+C to close the tunnel.\n'
  printf '  %s\n' "${urls[@]}"

  exec ssh -N -S none -o ExitOnForwardFailure=yes \
    -J "${JENKINS_SSH_USER}@galera.ii.pw.edu.pl" \
    "${forwards[@]}" \
    "${JENKINS_SSH_USER}@pis07.ii.pw.edu.pl"
}

open_service_tunnel() {
  local service=$1 default_port=$2
  shift 2
  if (( $# > 2 )); then
    usage >&2
    return 2
  fi
  open_tunnel "$service" "${1-$default_port}" "${2-$default_port}"
}

if (( $# == 0 )); then
  open_tunnel Jenkins 8080 8080 Nexus 8081 8081 Grafana 3001 3001 \
    Prometheus 9090 9090 SonarQube 9000 9000 GoStream 3000 3000
fi

case $1 in
  jenkins)
    shift
    open_service_tunnel Jenkins 8080 "$@"
    ;;
  nexus)
    shift
    open_service_tunnel Nexus 8081 "$@"
    ;;
  grafana)
    shift
    open_service_tunnel Grafana 3001 "$@"
    ;;
  prometheus|prom)
    shift
    open_service_tunnel Prometheus 9090 "$@"
    ;;
  sonarqube)
    shift
    open_service_tunnel SonarQube 9000 "$@"
    ;;
  app)
    shift
    open_service_tunnel GoStream 3000 "$@"
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
