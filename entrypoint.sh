#!/bin/bash
set -euo pipefail

MIHOMO_CONFIG_DIR="${MIHOMO_CONFIG_DIR:-/root/.config/mihomo}"
TUN_DEVICE="${TUN_DEVICE:-Mihomo}"
DIRECT_ALLOWLIST_TCP="${DIRECT_ALLOWLIST_TCP:-}"
DIRECT_ALLOWLIST_UDP="${DIRECT_ALLOWLIST_UDP:-}"
WORKSPACE_USER="${WORKSPACE_USER:-workspace}"
WORKSPACE_HOME="${WORKSPACE_HOME:-/home/${WORKSPACE_USER}}"
WORKSPACE_DIR="${WORKSPACE_DIR:-${WORKSPACE_HOME}/workspace}"
WORKSPACE_UID="${WORKSPACE_UID:-}"
WORKSPACE_GID="${WORKSPACE_GID:-}"
WORKSPACE_MODE="${WORKSPACE_MODE:-0}"
DESKTOP_MODE="${DESKTOP_MODE:-0}"

configure_resolver() {
  printf 'nameserver 127.0.0.1\noptions ndots:0\n' > /etc/resolv.conf
}

configure_workspace_user() {
  local detected_uid detected_gid group_name user_name current_group_name

  if [ -n "${WORKSPACE_DIR}" ] && [ -e "${WORKSPACE_DIR}" ]; then
    detected_uid="$(stat -c '%u' "${WORKSPACE_DIR}")"
    detected_gid="$(stat -c '%g' "${WORKSPACE_DIR}")"
    if [ -z "${WORKSPACE_UID}" ] && [ "${detected_uid}" != "0" ]; then
      WORKSPACE_UID="${detected_uid}"
    fi
    if [ -z "${WORKSPACE_GID}" ] && [ "${detected_gid}" != "0" ]; then
      WORKSPACE_GID="${detected_gid}"
    fi
  fi

  WORKSPACE_UID="${WORKSPACE_UID:-1000}"
  WORKSPACE_GID="${WORKSPACE_GID:-1000}"

  group_name="$(getent group "${WORKSPACE_GID}" | cut -d: -f1 || true)"
  if [ -z "${group_name}" ]; then
    group_name="${WORKSPACE_USER}"
    if getent group "${group_name}" >/dev/null 2>&1; then
      group_name="${WORKSPACE_USER}-${WORKSPACE_GID}"
    fi
    groupadd --gid "${WORKSPACE_GID}" "${group_name}"
  fi

  user_name="$(getent passwd "${WORKSPACE_UID}" | cut -d: -f1 || true)"
  if [ -z "${user_name}" ]; then
    user_name="${WORKSPACE_USER}"
    if getent passwd "${user_name}" >/dev/null 2>&1; then
      user_name="${WORKSPACE_USER}-${WORKSPACE_UID}"
    fi
    useradd \
      --uid "${WORKSPACE_UID}" \
      --gid "${WORKSPACE_GID}" \
      --home-dir "${WORKSPACE_HOME}" \
      --create-home \
      --shell /bin/bash \
      "${user_name}"
  else
    if [ "${user_name}" != "${WORKSPACE_USER}" ] && ! getent passwd "${WORKSPACE_USER}" >/dev/null 2>&1; then
      current_group_name="$(id -gn "${user_name}")"
      if [ "${current_group_name}" = "${user_name}" ] && ! getent group "${WORKSPACE_USER}" >/dev/null 2>&1; then
        groupmod -n "${WORKSPACE_USER}" "${current_group_name}"
      fi
      usermod --login "${WORKSPACE_USER}" "${user_name}"
      user_name="${WORKSPACE_USER}"
    fi

    usermod \
      --home "${WORKSPACE_HOME}" \
      --shell /bin/bash \
      "${user_name}"
  fi

  if ! id -nG "${user_name}" | tr ' ' '\n' | grep -qx sudo; then
    usermod -aG sudo "${user_name}"
  fi

  mkdir -p "${WORKSPACE_HOME}" "${WORKSPACE_DIR}"
  chown "${WORKSPACE_UID}:${WORKSPACE_GID}" "${WORKSPACE_HOME}"
  export HOME="${WORKSPACE_HOME}"
  export WORKSPACE_RUNTIME_USER="${user_name}"
  export WORKSPACE_RUNTIME_HOME="${WORKSPACE_HOME}"
  export WORKSPACE_RUNTIME_DIR="${WORKSPACE_DIR}"
  mkdir -p /run
  printf '%s\n' "${user_name}" > /run/workspace-user
  printf '%s\n' "${WORKSPACE_DIR}" > /run/workspace-dir
}

exec_as_workspace_user() {
  if ! configure_workspace_user; then
    exec "$@"
  fi

  exec setpriv \
    --reuid "${WORKSPACE_UID}" \
    --regid "${WORKSPACE_GID}" \
    --init-groups \
    env \
    HOME="${WORKSPACE_RUNTIME_HOME}" \
    USER="${WORKSPACE_RUNTIME_USER}" \
    LOGNAME="${WORKSPACE_RUNTIME_USER}" \
    SHELL="/bin/bash" \
    "$@"
}

apply_killswitch() {
  iptables -F OUTPUT
  iptables -P OUTPUT DROP
  iptables -A OUTPUT -o lo -j ACCEPT
  iptables -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
  iptables -A OUTPUT -o "${TUN_DEVICE}" -j ACCEPT

  if [ -n "${DIRECT_ALLOWLIST_TCP}" ]; then
    IFS=',' read -ra tcp_endpoints <<< "${DIRECT_ALLOWLIST_TCP}"
    for endpoint in "${tcp_endpoints[@]}"; do
      host="${endpoint%:*}"
      port="${endpoint##*:}"
      iptables -A OUTPUT -p tcp -d "${host}" --dport "${port}" -j ACCEPT
    done
  fi

  if [ -n "${DIRECT_ALLOWLIST_UDP}" ]; then
    IFS=',' read -ra udp_endpoints <<< "${DIRECT_ALLOWLIST_UDP}"
    for endpoint in "${udp_endpoints[@]}"; do
      host="${endpoint%:*}"
      port="${endpoint##*:}"
      iptables -A OUTPUT -p udp -d "${host}" --dport "${port}" -j ACCEPT
    done
  fi
}

apply_route_bypass() {
  local pref=100
  local endpoint host

  for endpoint_list in "${DIRECT_ALLOWLIST_TCP}" "${DIRECT_ALLOWLIST_UDP}"; do
    [ -n "${endpoint_list}" ] || continue
    IFS=',' read -ra endpoints <<< "${endpoint_list}"
    for endpoint in "${endpoints[@]}"; do
      host="${endpoint%:*}"
      if ! ip -4 rule show | grep -q "to ${host} lookup main"; then
        ip -4 rule add pref "${pref}" to "${host}" lookup main
        pref=$((pref + 1))
      fi
    done
  done

}

apply_ipv6_killswitch() {
  if [ "$(cat /proc/sys/net/ipv6/conf/all/disable_ipv6)" = "1" ]; then
    return
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

apply_killswitch
apply_route_bypass
apply_ipv6_killswitch
configure_resolver

if [ "${1:-}" = "bash" ] || [ "${1:-}" = "/bin/bash" ]; then
  start_mihomo_background
  echo "--- Proxy Started ---"
  echo "Current Public IP:"
  curl -fsS --connect-timeout 5 https://ifconfig.me || echo "Wait, connecting..."
  exec_as_workspace_user "$@"
fi

if [ "${DESKTOP_MODE}" = "1" ]; then
  start_mihomo_background
  exec_as_workspace_user /usr/local/bin/start-vnc-session
fi

if [ "${WORKSPACE_MODE}" = "1" ]; then
  start_mihomo_background
  exec_as_workspace_user "$@"
fi

exec /usr/local/bin/mihomo -d "${MIHOMO_CONFIG_DIR}" "$@"
