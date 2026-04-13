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
- Leave `DIRECT_ALLOWLIST_SUBNETS` empty unless you need extra private CIDRs beyond the Docker networks attached to `workspace`
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

To reach another service on the same Docker user-defined network, use the service
name directly, for example `mysql:3306`. Attached Docker bridge subnets are
allowed automatically and Docker's embedded DNS remains available inside the
container. Add `DIRECT_ALLOWLIST_SUBNETS` only when you need extra private CIDRs
that are not attached to `workspace`.
