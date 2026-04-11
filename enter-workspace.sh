#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

service="workspace"

if [ $# -eq 0 ]; then
  shell_command=(bash -il)
else
  shell_command=("$@")
fi

workspace_user=""
for _ in $(seq 1 20); do
  workspace_user="$(docker compose exec -T "${service}" sh -lc 'cat /run/workspace-user 2>/dev/null || true')"
  if [ -n "${workspace_user}" ]; then
    break
  fi
  sleep 0.5
done

if [ -z "${workspace_user}" ]; then
  echo "workspace user is not ready in service '${service}'" >&2
  exit 1
fi

workspace_home="$(docker compose exec -T "${service}" sh -lc "getent passwd '${workspace_user}' | cut -d: -f6")"
if [ -z "${workspace_home}" ]; then
  echo "workspace home is not ready for user '${workspace_user}' in service '${service}'" >&2
  exit 1
fi

workspace_dir="$(docker compose exec -T "${service}" sh -lc 'cat /run/workspace-dir 2>/dev/null || true')"
if [ -z "${workspace_dir}" ]; then
  workspace_dir="${workspace_home}/workspace"
fi

exec docker compose exec \
  -u "${workspace_user}" \
  -w "${workspace_dir}" \
  -e HOME="${workspace_home}" \
  -e USER="${workspace_user}" \
  -e LOGNAME="${workspace_user}" \
  -e SHELL="/bin/bash" \
  -e TERM="${TERM:-xterm-256color}" \
  "${service}" "${shell_command[@]}"
