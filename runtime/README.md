# Runtime Package

This directory is the runtime-only entrypoint for published images. It does not
build local Dockerfiles.

## Files

- `docker-compose.yml`: runtime-only Compose file
- `.env.example`: runtime environment template
- `config.example.yaml`: Mihomo config template
- `enter-workspace.sh`: enter the running container as the mapped user

## Quick Start

1. Copy the templates:

```bash
cp .env.example .env
cp config.example.yaml config.yaml
chmod +x enter-workspace.sh
mkdir -p logs
```

2. Edit `.env`:

- Set `WORKSPACE_MOUNT` to an absolute host path
  If you leave it unset, Compose defaults to `./workspace` under this directory.
- For desktop mode, set `VNC_PASSWORD`

3. Edit `config.yaml`:

- Replace the sample proxy servers and credentials
- `tun.route-exclude-address` is the single source of truth for the direct-connect allowlist — it drives both Mihomo's TUN exclusion and the iptables killswitch/route-bypass rules
- Keep `device: Mihomo` unless you also change `.env`

4. Start:

```bash
docker compose pull
docker compose up -d
```

5. Enter:

```bash
./enter-workspace.sh
```

Desktop mode uses `ghcr.io/qjp88995/safe-proxy-workspace-desktop:latest` by
default. Switch to `ghcr.io/qjp88995/safe-proxy-workspace:latest` and set
`DESKTOP_MODE=0` if you want the CLI image instead.

## Changing the allowlist

To point at different proxy endpoints, edit `route-exclude-address` (and the
matching `proxies[*].server`) in `config.yaml`, then reload without
recreating the container:

```bash
docker compose exec workspace reload-proxy
```

`reload-proxy` re-applies the killswitch/route-bypass rules and restarts
Mihomo; installed system software and the workspace home volume are
untouched. `docker restart` on the container re-applies the same policy
automatically through the entrypoint.

The `reload-proxy` command ships inside the image itself — `docker compose
pull` to the latest tag before using it if your running container predates
this feature.

## Docker-out-of-Docker

Both images include the Docker CLI. To manage the host's Docker from inside the workspace:

1. In `.env`, set `DOCKER_GID` to the host's `docker` group GID:

```bash
DOCKER_GID=996   # getent group docker | cut -d: -f3
```

2. In `docker-compose.yml`, uncomment the docker socket mount:

```yaml
volumes:
  - /var/run/docker.sock:/var/run/docker.sock
```

3. Recreate the container:

```bash
docker compose up -d
```

The entrypoint automatically adds the workspace user to the `docker` group.

Note: containers started this way run on the host's Docker daemon, outside the workspace's proxy chain.
