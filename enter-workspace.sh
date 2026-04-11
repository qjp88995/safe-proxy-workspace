#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

service="workspace"

if [ $# -eq 0 ]; then
  shell_command=(bash)
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

exec docker compose exec -u "${workspace_user}" "${service}" "${shell_command[@]}"
