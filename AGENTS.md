# safe-proxy-workspace Agent Notes

## Project Summary

This repository provides a fail-closed Docker workspace that routes container egress through Mihomo.

Core behavior:

- The main service is `workspace` in `docker-compose.yml`.
- Outbound traffic is allowed only through the Mihomo TUN device, except for explicitly allowlisted proxy endpoints.
- If the proxy chain fails, the container should lose external connectivity instead of leaking the host IP.
- The host project directory is mounted into the container at `~/workspace`.
- The in-container user is mapped to the mounted directory UID/GID when possible.

## Main Runtime Flow

1. `docker compose up -d` builds or starts the `workspace` container.
2. `entrypoint.sh` applies the IPv4/IPv6 kill switch, route bypass, DNS override, and workspace user mapping.
3. `entrypoint.sh` starts Mihomo in the background for workspace and desktop modes.
4. `enter-workspace.sh` discovers the mapped runtime user and enters the container with the correct `HOME`, user, and working directory.

## Modes

CLI mode:

- Uses `Dockerfile`
- Typical `.env` values:
  - `DOCKERFILE=Dockerfile`
  - `DESKTOP_MODE=0`

Desktop/VNC mode:

- Uses `Dockerfile.desktop`
- Starts XFCE through `desktop-session.sh`
- Requires `VNC_PASSWORD`
- Typical `.env` values:
  - `DOCKERFILE=Dockerfile.desktop`
  - `DESKTOP_MODE=1`

## Files That Matter

- `docker-compose.yml`: single `workspace` service, env wiring, volume mounts, TUN device, capabilities, VNC port, `/dev/shm`
- `entrypoint.sh`: kill switch, direct allowlist rules, route bypass, resolver setup, workspace user creation/mapping
- `enter-workspace.sh`: preferred way to enter the running container as the mapped user
- `Dockerfile`: CLI image
- `Dockerfile.desktop`: desktop/VNC image
- `desktop-session.sh`: TigerVNC + XFCE startup
- `workspace-shell.sh`: prompt and shell quality-of-life defaults for interactive sessions
- `config.example.yaml`: public Mihomo template
- `docs/software-installation.md`: post-start software installation notes
- `docs/software-installation.zh-CN.md`: Chinese version of the same notes

## Critical Invariants

- `.env` `DIRECT_ALLOWLIST_TCP` and `DIRECT_ALLOWLIST_UDP` must match the proxy endpoints excluded in `config.yaml` `tun.route-exclude-address`.
- `TUN_DEVICE` should stay aligned with the Mihomo config device name. Default is `Mihomo`.
- This project is Linux-only because it depends on Docker, `/dev/net/tun`, and iptables/ip6tables behavior.
- IPv6 is intentionally disabled or blocked to reduce leak paths.

## Common Commands

Start or rebuild:

```bash
docker compose up -d --build
```

Enter workspace:

```bash
./enter-workspace.sh
```

View logs:

```bash
docker compose logs -f workspace
```

Check exit IP:

```bash
docker compose exec workspace curl -4 --max-time 15 https://ifconfig.me
```

Stop:

```bash
docker compose down
```

## Change Guidance

- Preserve the fail-closed networking model. Any change that weakens the kill switch or bypass rules needs extra scrutiny.
- When changing `entrypoint.sh`, verify both workspace mode and desktop mode startup paths.
- When changing compose env names or defaults, keep `README.md`, `README.zh-CN.md`, and examples in sync.
- Do not commit secrets or local runtime files such as `.env`, `config.yaml`, or `logs/`.

## Good First Read For Future Agents

Read in this order:

1. `README.md`
2. `docker-compose.yml`
3. `entrypoint.sh`
4. `enter-workspace.sh`
5. `Dockerfile` or `Dockerfile.desktop`, depending on the mode being changed
