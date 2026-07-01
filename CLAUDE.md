## Project Overview

A fail-closed Docker workspace powered by Mihomo (Clash Meta). All container egress goes through a TUN-based proxy chain; traffic is dropped rather than leaked if the chain is unavailable.

## Security Model — Single Allowlist Source

The direct-connect allowlist has one source of truth: `config.yaml` →
`tun.route-exclude-address`. It feeds both mihomo's TUN exclusion and the
iptables killswitch / route-bypass (parsed at container start and on reload).

Change proxy endpoints by editing `route-exclude-address` (and the matching
`proxies[*].server`) in `config.yaml`, then run `reload-proxy` inside the
container — no recreate needed, installed system software is preserved.

## Key Files

| File | Role |
| --- | --- |
| `entrypoint.sh` | Sets iptables killswitch, route bypass, IPv6 block, DNS, UID/GID mapping, then starts Mihomo |
| `Dockerfile` | CLI image |
| `Dockerfile.desktop` | Desktop/VNC image (XFCE + TigerVNC, Chrome on amd64) |
| `docker-compose.yml` | Single `workspace` service; extend it with companion services as needed |
| `config.yaml` | Mihomo config (gitignored — never commit) |
| `.env` | Compose env (gitignored — never commit) |
| `skel/` | Shell startup files copied into a fresh workspace home |

## Companion Services

Services that need to be reachable from inside the workspace (e.g. PostgreSQL) should use `network_mode: "service:workspace"` to share the workspace network namespace. The killswitch already allows loopback traffic, so no image changes are needed. See `docs/companion-services.md` for details and a full example.

Do not suggest installing such services inside the workspace container with `apt-get` — `systemctl` is not available inside Docker.

## Documentation

- All docs live under `docs/`.
- Every doc must have both an English version and a Chinese version (`*.zh-CN.md`).
- Both README files (`README.md` and `README.zh-CN.md`) must be kept in sync when adding new doc references.

## Files Never to Commit

- `.env`
- `config.yaml`
- `logs/`
