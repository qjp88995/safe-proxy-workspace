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

## When the Proxy Endpoint Is a Domain

Subscription configs often set `proxies[*].server` to a **domain name** rather than an IP. That will not work as-is, because `tun.route-exclude-address` — the single source that feeds the iptables killswitch and route-bypass — can only be an IP or CIDR. iptables and `ip rule` cannot match domains, so a domain entry there is silently skipped, the killswitch drops Mihomo's connection to the upstream node, and `reload-proxy` reports the network as unreachable (fail-closed).

Pick one of the two approaches below. In both, `route-exclude-address` **must** be an IP.

First resolve the domain to its IP (e.g. `getent hosts your.domain.com` or `nslookup your.domain.com`). Assume it is `1.2.3.4`.

**Option A — use the IP directly (simplest).** Put the IP in both places:

```yaml
proxies:
  - name: "..."
    server: 1.2.3.4          # IP instead of the domain
tun:
  route-exclude-address:
    - 1.2.3.4/32
```

**Option B — keep the domain (stay aligned with the subscription).** Keep the domain in `server` and pin it to the IP with a `hosts` mapping so Mihomo resolves it locally instead of sending a DNS query (which the killswitch would drop):

```yaml
hosts:
  "your.domain.com": 1.2.3.4

proxies:
  - name: "..."
    server: your.domain.com  # domain preserved, resolved via hosts

tun:
  route-exclude-address:
    - 1.2.3.4/32             # always the IP
```

The `hosts` key is read by Mihomo only; the project scripts never parse it, so **no code changes are needed** — editing `config.yaml` and running `reload-proxy` is enough.

> **Caveat:** Both the `hosts` IP and the `route-exclude-address` IP are hardcoded. A domain is usually used precisely because its IP can change; if the node's IP rotates, both lines go stale and egress breaks. When that happens, re-resolve the domain, update both IPs, and run `reload-proxy` again.

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
