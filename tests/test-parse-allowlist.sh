#!/usr/bin/env bash
# 纯函数单元测试：无需 root/容器，直接在宿主机运行。
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/proxy-network.sh"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT
export MIHOMO_CONFIG_DIR="${TMP_DIR}"

cat > "${TMP_DIR}/config.yaml" <<'YAML'
log-level: info

tun:
  enable: true
  device: Mihomo
  route-exclude-address:
    - 203.0.113.10/32
    - "198.51.100.20/32"   # inline comment
    - 10.0.0.0/8
  dns-hijack:
    - any:53

dns:
  enable: true
YAML

expected='203.0.113.10/32
198.51.100.20/32
10.0.0.0/8'

actual="$(parse_route_exclude_addresses)"

if [ "${actual}" = "${expected}" ]; then
  echo "PASS: parse_route_exclude_addresses"
  exit 0
else
  echo "FAIL: parse_route_exclude_addresses"
  echo "--- expected ---"; printf '%s\n' "${expected}"
  echo "--- actual ---"; printf '%s\n' "${actual}"
  exit 1
fi
