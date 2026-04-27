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
- Set `DIRECT_ALLOWLIST_TCP` and `DIRECT_ALLOWLIST_UDP` to the same proxy endpoints as `config.yaml`
- For desktop mode, set `VNC_PASSWORD`

3. Edit `config.yaml`:

- Replace the sample proxy servers and credentials
- Keep `tun.route-exclude-address` aligned with `.env`
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
