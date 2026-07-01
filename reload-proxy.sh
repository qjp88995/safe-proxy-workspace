#!/usr/bin/env bash
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "reload-proxy 需以 root 运行。请用：" >&2
  echo "  docker compose exec workspace reload-proxy" >&2
  echo "或在 workspace 内：sudo reload-proxy" >&2
  exit 1
fi

# shellcheck source=/dev/null
source /usr/local/lib/proxy-network.sh

echo "--- Reloading proxy policy from config.yaml ---"
apply_killswitch
apply_route_bypass
apply_ipv6_killswitch
restart_mihomo

echo "--- Proxy reloaded. Current public IP: ---"
curl -fsS --connect-timeout 5 https://ifconfig.me || echo "(尚未连通，请稍候重试或检查 config.yaml)"
echo
