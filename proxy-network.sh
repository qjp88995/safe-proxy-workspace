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

apply_killswitch() {
  local addr
  iptables -F OUTPUT
  iptables -P OUTPUT DROP
  iptables -A OUTPUT -o lo -j ACCEPT
  iptables -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
  iptables -A OUTPUT -o "${TUN_DEVICE}" -j ACCEPT

  while IFS= read -r addr; do
    [ -n "${addr}" ] || continue
    iptables -A OUTPUT -p tcp -d "${addr}" -j ACCEPT
    iptables -A OUTPUT -p udp -d "${addr}" -j ACCEPT
  done < <(parse_route_exclude_addresses)
}

apply_route_bypass() {
  local pref=100
  local addr p

  # 先清空我们管理的 pref 段，保证 reload 时不残留旧节点规则。
  for ((p = 100; p <= 199; p++)); do
    ip -4 rule del pref "${p}" 2>/dev/null || true
  done

  while IFS= read -r addr; do
    [ -n "${addr}" ] || continue
    ip -4 rule add pref "${pref}" to "${addr}" lookup main
    pref=$((pref + 1))
  done < <(parse_route_exclude_addresses)
}

apply_ipv6_killswitch() {
  if [ "$(cat /proc/sys/net/ipv6/conf/all/disable_ipv6)" = "1" ]; then
    return 0
  fi
  ip6tables -F OUTPUT
  ip6tables -P OUTPUT DROP
  ip6tables -A OUTPUT -o lo -j ACCEPT
  ip6tables -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
  ip6tables -A OUTPUT -o "${TUN_DEVICE}" -j ACCEPT
}

start_mihomo_background() {
  /usr/local/bin/mihomo -d "${MIHOMO_CONFIG_DIR}" > /var/log/mihomo.log 2>&1 &
  sleep 2
}

restart_mihomo() {
  local i
  pkill -x mihomo 2>/dev/null || true
  for ((i = 0; i < 50; i++)); do
    pgrep -x mihomo >/dev/null 2>&1 || break
    sleep 0.1
  done
  # setsid 使新 mihomo 脱离当前（docker exec）会话，reparent 到 PID1 并存活。
  setsid /usr/local/bin/mihomo -d "${MIHOMO_CONFIG_DIR}" </dev/null >> /var/log/mihomo.log 2>&1 &
  sleep 2
}
