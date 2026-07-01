#!/usr/bin/env bash
# 代理网络策略函数库：被 entrypoint.sh（boot）与 reload-proxy（运行时）source。
# source 时只定义函数与默认变量，不执行副作用。

: "${MIHOMO_CONFIG_DIR:=/root/.config/mihomo}"
: "${TUN_DEVICE:=Mihomo}"

# 校验字符串是否为 IPv4 地址或 IPv4 CIDR。用于在把地址交给 iptables/ip 之前
# 过滤掉手改 config.yaml 时写错的条目，避免单个坏地址在 set -e 下中断整个
# killswitch/route 应用（导致 boot 崩溃重启或 reload 只应用一半规则）。
_is_ipv4_cidr() {
  [[ "$1" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}(/[0-9]{1,2})?$ ]]
}

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
  iptables -P OUTPUT DROP
  iptables -F OUTPUT
  iptables -A OUTPUT -o lo -j ACCEPT
  iptables -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
  iptables -A OUTPUT -o "${TUN_DEVICE}" -j ACCEPT

  while IFS= read -r addr; do
    [ -n "${addr}" ] || continue
    if ! _is_ipv4_cidr "${addr}"; then
      echo "proxy-network: skipping invalid route-exclude-address (killswitch): ${addr}" >&2
      continue
    fi
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
    if ! _is_ipv4_cidr "${addr}"; then
      echo "proxy-network: skipping invalid route-exclude-address (route-bypass): ${addr}" >&2
      continue
    fi
    ip -4 rule add pref "${pref}" to "${addr}" lookup main
    pref=$((pref + 1))
  done < <(parse_route_exclude_addresses)
}

apply_ipv6_killswitch() {
  if [ "$(cat /proc/sys/net/ipv6/conf/all/disable_ipv6)" = "1" ]; then
    return 0
  fi
  ip6tables -P OUTPUT DROP
  ip6tables -F OUTPUT
  ip6tables -A OUTPUT -o lo -j ACCEPT
  ip6tables -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
  ip6tables -A OUTPUT -o "${TUN_DEVICE}" -j ACCEPT
}

start_mihomo_background() {
  /usr/local/bin/mihomo -d "${MIHOMO_CONFIG_DIR}" > /var/log/mihomo.log 2>&1 &
  sleep 2
}

restart_mihomo() {
  local i live
  pkill -x mihomo 2>/dev/null || true
  # 等待存活的 mihomo 退出。被杀的 mihomo 在 PID1 回收前会残留为 <defunct>
  # 僵尸，pgrep 仍会匹配到它，因此这里只统计非僵尸（状态非 Z）的进程，
  # 避免空等到超时。
  for ((i = 0; i < 50; i++)); do
    live="$(ps -o stat= -C mihomo 2>/dev/null | grep -vc '^Z' || true)"
    [ "${live:-0}" = "0" ] && break
    sleep 0.1
  done
  # setsid 使新 mihomo 脱离当前（docker exec）会话，reparent 到 PID1 并存活。
  setsid /usr/local/bin/mihomo -d "${MIHOMO_CONFIG_DIR}" </dev/null >> /var/log/mihomo.log 2>&1 &
  sleep 2
}
