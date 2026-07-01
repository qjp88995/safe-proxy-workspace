# Installing Common Software

Enter the workspace first:

```bash
./enter-workspace.sh
```

Then update the package index and upgrade installed packages:

```bash
sudo apt-get update
sudo apt-get dist-upgrade
```

If you need to configure the timezone, run:

```bash
sudo dpkg-reconfigure tzdata
```

The mapped user's home directory is persisted in the Docker volume `workspace_home`, so changes under `~` survive container rebuilds. System packages installed with `sudo apt-get install ...` still belong to the image filesystem; if you need them every time, prefer baking them into the relevant Dockerfile.

Changing the proxy allowlist (`tun.route-exclude-address` in `config.yaml`) no longer requires recreating the container. Run `docker compose exec workspace reload-proxy` (or `sudo reload-proxy` inside the workspace) after editing `config.yaml` — it reloads the killswitch/route-bypass rules and restarts Mihomo in place, so any `apt-get`-installed packages from this session are preserved.

## UTF-8 Locale

The images now generate and enable `en_US.UTF-8` at the system level by default. A terminal opened inside the VNC desktop should therefore already report UTF-8.

Verify it with:

```bash
locale
python3 -c 'import locale; print(locale.getpreferredencoding(False))'
```

If you still see `ANSI_X3.4-1968` or `POSIX`, that usually means an older container is still running and needs to be recreated:

```bash
docker compose up -d --build
```

## Google Chrome

On `amd64`, `Dockerfile.desktop` already preinstalls Google Chrome in desktop/VNC mode. Because the workspace home directory is persisted, Chrome keeps its profile, cookies, and login state across container rebuilds.

If you are building the desktop image for another architecture, Chrome is not preinstalled by this repository.
