# safe-proxy-workspace

[中文说明](README.zh-CN.md)

A fail-closed Docker workspace powered by Mihomo. Traffic inside the container either goes through your SS relay chain or gets blocked.

## What this project does

- Runs a long-lived workspace container with Mihomo inside
- Forces container egress through a TUN-based relay chain
- Only allows direct connections to your proxy endpoints
- Blocks all other outbound traffic if the proxy chain is unavailable
- Gives the user a normal home directory while mounting the host workspace at `~/workspace`
- Persists the mapped user's home directory in a Docker volume across container rebuilds

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
- Leave `DIRECT_ALLOWLIST_SUBNETS` empty unless you need to allow extra private subnets beyond the Docker networks attached to `workspace`
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

Inside the container, the mapped user gets a normal home directory at `/home/$WORKSPACE_USER`, and the host project is mounted at `~/workspace`. The home directory is stored in the Docker volume `workspace_home`, so shell dotfiles, browser profiles, and user-level tools survive `docker compose up --build` and container recreation. Change `WORKSPACE_USER` in `.env` if you want a different username and home directory name. The mapped user can use passwordless `sudo` to install packages and manage personal tools like on a regular Ubuntu workstation.

Both the CLI image and the desktop image preinstall `git` and the OpenSSH client, so `git clone git@...` and direct `ssh` commands work after you rebuild the container.

For package updates and common software installation steps, see [Installing common software](docs/software-installation.md).

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
DESKTOP_SHM_SIZE=2gb
```

The desktop container also adds `SYS_ADMIN` so GUI browsers such as Google Chrome can use their Linux sandbox inside Docker. If you previously launched Chrome with `--no-sandbox`, remove that flag after recreating the container.
On `amd64`, the desktop image also preinstalls Google Chrome. Because the workspace home directory is persisted, Chrome keeps its profile data and login state across container rebuilds.

Then start the same service as usual:

```bash
docker compose up -d
```

In desktop mode, connect your VNC client to `127.0.0.1:5901` by default. The published port binds to `127.0.0.1` unless you change `DESKTOP_VNC_BIND`.

The desktop container also sets a larger `/dev/shm` segment by default because GUI browsers such as Google Chrome can crash in containerized VNC sessions when shared memory is limited to Docker's default 64 MB. If needed, tune it with `DESKTOP_SHM_SIZE`.

## Using a different workspace directory

```bash
WORKSPACE_MOUNT=/your/project/path docker compose up -d
./enter-workspace.sh
```

Files created under `~/workspace` will be written with the same UID/GID as the host directory whenever possible.

## Accessing other Docker services

`workspace` can now reach other containers on the same Docker user-defined network by service name such as `mysql:3306`.

- Keep `workspace` and the target service on the same user-defined Docker network
- Docker-attached IPv4 subnets are detected automatically and allowed to bypass Mihomo
- Docker's embedded DNS is preserved so service names such as `mysql` continue to resolve inside the container
- If you need additional private CIDRs beyond the attached Docker networks, add them to `DIRECT_ALLOWLIST_SUBNETS` as a comma-separated list

Minimal example:

```yaml
services:
  workspace:
    networks:
      - backend

  postgres:
    image: postgres:16
    restart: unless-stopped
    environment:
      POSTGRES_DB: app
      POSTGRES_USER: app
      POSTGRES_PASSWORD: app-dev-password
    volumes:
      - postgres_data:/var/lib/postgresql/data
    networks:
      - backend

volumes:
  postgres_data:

networks:
  backend:
    driver: bridge
```

Then connect from code inside `workspace` with:

```text
postgresql://app:app-dev-password@postgres:5432/app
```

The network name `backend` is only an example. The hostname comes from the service name `postgres`, so any user-defined network name works as long as both services join the same network.

This only opens directly attached private networks. Internet traffic still follows the fail-closed Mihomo path.

## Persistent home directory

The mapped user's home directory is stored in the Docker volume `workspace_home`.

That keeps these across rebuilds and container replacement:

- `~/.bashrc`, `~/.profile`, and related shell startup files
- Browser data such as `~/.config/google-chrome`
- User-level tool state such as `~/.npm`, `~/.local`, and `~/.config`

To remove that persisted state and start from a clean home directory:

```bash
docker compose down -v
```

## Using a prebuilt image

Tagged releases are published to GHCR.

If you want a runtime-only setup for end users, use the files under [runtime](/home/calf/projects/safe-proxy-workspace/runtime/README.md:1). That package only needs these local files:

- `runtime/docker-compose.yml`
- `.env`
- `config.yaml`
- `runtime/enter-workspace.sh`

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
cd runtime
docker compose pull
docker compose up -d
```

If you use Google Chrome in desktop mode, recreate the container after updating so the browser can start with its sandbox enabled instead of showing the `--no-sandbox` warning. On `amd64`, the desktop image already includes Chrome.

## Security model

This project is designed to be fail-closed:

- Proxy endpoints themselves may connect directly
- Directly attached Docker private subnets may connect directly
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
| `runtime/` | Runtime-only package for published images |
| `entrypoint.sh` | Sets up kill switch, route bypass, resolver, and UID/GID mapping |
| `desktop-session.sh` | Starts the XFCE session inside TigerVNC |
| `enter-workspace.sh` | Enters the container as the mapped workspace user |
| `skel/` | Default shell startup files copied into a new workspace home |
| `config.example.yaml` | Public Mihomo config template |
| `.env.example` | Public Compose env template |

## Files you should not commit

- `.env`
- `config.yaml`
- `logs/`
