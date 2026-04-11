#!/bin/bash
set -euo pipefail

VNC_PASSWORD="${VNC_PASSWORD:-}"
VNC_DISPLAY="${VNC_DISPLAY:-1}"
VNC_GEOMETRY="${VNC_GEOMETRY:-1440x900}"
VNC_DEPTH="${VNC_DEPTH:-24}"
VNC_LOCALHOST="${VNC_LOCALHOST:-no}"

if [ -z "${VNC_PASSWORD}" ]; then
  echo "VNC_PASSWORD must be set when DESKTOP_MODE=1" >&2
  exit 1
fi

case "${VNC_DISPLAY}" in
  ''|*[!0-9]*)
    echo "VNC_DISPLAY must be a positive integer, got '${VNC_DISPLAY}'" >&2
    exit 1
    ;;
esac

if [ "${VNC_DISPLAY}" -lt 1 ]; then
  echo "VNC_DISPLAY must be at least 1, got '${VNC_DISPLAY}'" >&2
  exit 1
fi

mkdir -p "${HOME}/.vnc"
printf '%s\n' "${VNC_PASSWORD}" | vncpasswd -f > "${HOME}/.vnc/passwd"
chmod 600 "${HOME}/.vnc/passwd"

cat > "${HOME}/.vnc/xstartup" <<'EOF'
#!/bin/sh
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
export XDG_SESSION_DESKTOP=xfce
export XDG_CURRENT_DESKTOP=XFCE
export XDG_SESSION_TYPE=x11
exec dbus-launch --exit-with-session startxfce4
EOF
chmod +x "${HOME}/.vnc/xstartup"

exec tigervncserver \
  -fg \
  ":${VNC_DISPLAY}" \
  -geometry "${VNC_GEOMETRY}" \
  -depth "${VNC_DEPTH}" \
  -localhost "${VNC_LOCALHOST}" \
  -SecurityTypes VncAuth
