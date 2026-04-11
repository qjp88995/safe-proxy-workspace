# safe-proxy-workspace

A fail-closed Docker workspace powered by Mihomo. Traffic inside the container either goes through your SS relay chain or gets blocked.

## What this project does

- Runs a long-lived workspace container with Mihomo inside
- Forces container egress through a TUN-based relay chain
- Only allows direct connections to your proxy endpoints
- Blocks all other outbound traffic if the proxy chain is unavailable
- Keeps files created under the mounted workspace aligned with the host UID/GID

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

4. Start the container:

```bash
docker compose up -d
```

5. Enter the workspace:

```bash
./enter-workspace.sh
```

6. Check the exit IP:

```bash
docker compose exec workspace curl -4 --max-time 15 https://ifconfig.me
```

## Using a different workspace directory

```bash
WORKSPACE_MOUNT=/your/project/path docker compose up -d
./enter-workspace.sh
```

Files created under `/workspace` will be written with the same UID/GID as the mounted host directory whenever possible.

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

To make Compose use a published image, set this in `.env`:

```bash
IMAGE_NAME=ghcr.io/qjp88995/safe-proxy-workspace:latest
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
| `docker-compose.yml` | Runs the workspace container |
| `entrypoint.sh` | Sets up kill switch, route bypass, resolver, and UID/GID mapping |
| `enter-workspace.sh` | Enters the container as the mapped workspace user |
| `config.example.yaml` | Public Mihomo config template |
| `.env.example` | Public Compose env template |

## Files you should not commit

- `.env`
- `config.yaml`
- `logs/`
