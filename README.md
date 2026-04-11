# safe-proxy-workspace

[中文说明](README.zh-CN.md)

A fail-closed Docker workspace powered by Mihomo. Traffic inside the container either goes through your SS relay chain or gets blocked.

## What this project does

- Runs a long-lived workspace container with Mihomo inside
- Forces container egress through a TUN-based relay chain
- Only allows direct connections to your proxy endpoints
- Blocks all other outbound traffic if the proxy chain is unavailable
- Gives the user a normal home directory while mounting the host workspace at `~/workspace`

## Requirements

- Linux host
- Docker Engine with Docker Compose
- `/dev/net/tun` available on the host
- Reachable SS proxy nodes

## Quick start

1. Copy the local config files:

```bash
cp .env.example .env
cp config.example.yaml config.yaml
```

2. Edit `config.yaml`:

- Replace the sample SS servers, ports, ciphers, and passwords
- Keep `tun.route-exclude-address` set to the proxy node IPs
- Keep `device: Mihomo` unchanged unless you also change `.env`

3. Edit `.env`:

- Set `DIRECT_ALLOWLIST_TCP` and `DIRECT_ALLOWLIST_UDP` to the same proxy `IP:PORT` pairs from `config.yaml`
- Set `WORKSPACE_MOUNT` if you want to mount a different host directory
- Set `WORKSPACE_USER` if you want a different in-container username and home path

4. Start the container:

```bash
docker compose up -d
```

5. Enter the workspace:

```bash
./enter-workspace.sh
```

This helper preserves the mapped user's `HOME` and shell environment, starts inside `~/workspace`, and keeps the interactive Bash prompt and color output working as expected.

Inside the container, the mapped user gets a normal home directory at `/home/$WORKSPACE_USER`, and the host project is mounted at `~/workspace`. Change `WORKSPACE_USER` in `.env` if you want a different username and home directory name. The mapped user can use passwordless `sudo` to install packages and manage personal tools like on a regular Ubuntu workstation.

6. Check the exit IP:

```bash
docker compose exec workspace curl -4 --max-time 15 https://ifconfig.me
```

## Switching between CLI and desktop images

Compose now manages a single `workspace` service. Switch it between the CLI image and the desktop/VNC image by changing `.env`.

CLI mode:

```bash
IMAGE_NAME=safe-proxy-workspace:latest
DOCKERFILE=Dockerfile
DESKTOP_MODE=0
```

Desktop/VNC mode:

```bash
IMAGE_NAME=safe-proxy-workspace-desktop:latest
DOCKERFILE=Dockerfile.desktop
DESKTOP_MODE=1
VNC_PASSWORD=replace-this-before-use
```

Then start the same service as usual:

```bash
docker compose up -d
```

In desktop mode, connect your VNC client to `127.0.0.1:5901` by default. The published port binds to `127.0.0.1` unless you change `DESKTOP_VNC_BIND`.

## Using a different workspace directory

```bash
WORKSPACE_MOUNT=/your/project/path docker compose up -d
./enter-workspace.sh
```

Files created under `~/workspace` will be written with the same UID/GID as the host directory whenever possible.

## Using a prebuilt image

Tagged releases are published to GHCR.

Pull a release image:

```bash
docker pull ghcr.io/qjp88995/safe-proxy-workspace:v0.0.1
```

Or use the latest published image:

```bash
docker pull ghcr.io/qjp88995/safe-proxy-workspace:latest
```

Desktop/VNC image:

```bash
docker pull ghcr.io/qjp88995/safe-proxy-workspace-desktop:latest
```

To make Compose use a published image, set this in `.env`:

```bash
IMAGE_NAME=ghcr.io/qjp88995/safe-proxy-workspace:latest
DOCKERFILE=Dockerfile
DESKTOP_MODE=0
```

Or switch the same `workspace` service to the desktop image:

```bash
IMAGE_NAME=ghcr.io/qjp88995/safe-proxy-workspace-desktop:latest
DOCKERFILE=Dockerfile.desktop
DESKTOP_MODE=1
VNC_PASSWORD=replace-this-before-use
```

Then pull and start:

```bash
docker compose pull
docker compose up -d
```

## Security model

This project is designed to be fail-closed:

- Proxy endpoints themselves may connect directly
- All other outbound traffic must go through the `Mihomo` TUN interface
- If the relay chain stops working, the container loses external connectivity instead of falling back to the host's real IP
- IPv6 is disabled to reduce leak paths

Two places must stay in sync:

1. `.env`: `DIRECT_ALLOWLIST_TCP` and `DIRECT_ALLOWLIST_UDP`
2. `config.yaml`: `tun.route-exclude-address`

They must describe the same proxy endpoints.

## Daily commands

Start or restart:

```bash
docker compose up -d --build
```

Enter the workspace:

```bash
./enter-workspace.sh
```

View logs:

```bash
docker compose logs -f workspace
```

Stop the container:

```bash
docker compose down
```

## GitHub Actions

`.github/workflows/docker-image.yaml` builds and pushes the image to GHCR when you push a tag like `v0.0.1`.

It also supports manual runs through `workflow_dispatch`.

## Repository layout

| File | Purpose |
| --- | --- |
| `Dockerfile` | Builds the image |
| `Dockerfile.desktop` | Builds the preinstalled desktop/VNC image |
| `docker-compose.yml` | Runs the single workspace container and mounts the host project at `~/workspace` |
| `entrypoint.sh` | Sets up kill switch, route bypass, resolver, and UID/GID mapping |
| `desktop-session.sh` | Starts the XFCE session inside TigerVNC |
| `enter-workspace.sh` | Enters the container as the mapped workspace user |
| `config.example.yaml` | Public Mihomo config template |
| `.env.example` | Public Compose env template |

## Files you should not commit

- `.env`
- `config.yaml`
- `logs/`
