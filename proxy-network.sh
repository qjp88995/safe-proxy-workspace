#!/usr/bin/env bash
# 代理网络策略函数库：被 entrypoint.sh（boot）与 reload-proxy（运行时）source。
# source 时只定义函数与默认变量，不执行副作用。

: "${MIHOMO_CONFIG_DIR:=/root/.config/mihomo}"
: "${TUN_DEVICE:=Mihomo}"

# 从 config.yaml 的 tun.route-exclude-address 解析出 IP/CIDR 列表，每行一个。
parse_route_exclude_addresses() {
  local config_file="${MIHOMO_CONFIG_DIR}/config.yaml"
  [ -f "${config_file}" ] || return 0

  awk '
    /^[[:space:]]*route-exclude-address:[[:space:]]*(#.*)?$/ {
      match($0, /^[[:space:]]*/); key_indent = RLENGTH
      in_block = 1
      next
    }
    in_block {
      if ($0 ~ /^[[:space:]]*$/ || $0 ~ /^[[:space:]]*#/) { next }
      match($0, /^[[:space:]]*/); line_indent = RLENGTH
      if (line_indent > key_indent && $0 ~ /^[[:space:]]*-[[:space:]]*/) {
        val = $0
        sub(/^[[:space:]]*-[[:space:]]*/, "", val)   # 去掉 "- "
        sub(/[[:space:]]*#.*$/, "", val)             # 去掉行内注释
        gsub(/[\047\042]/, "", val)                  # 去掉单/双引号
        gsub(/[[:space:]]+/, "", val)                # 去掉空白
        if (val != "") print val
        next
      }
      in_block = 0
    }
  ' "${config_file}"
}
