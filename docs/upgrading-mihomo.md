# Upgrading Mihomo

The Mihomo binary is baked into the image at build time. Its version is set by the `MIHOMO_VERSION` build argument in `Dockerfile` and `Dockerfile.desktop`, and the binary lives at `/usr/local/bin/mihomo`.

Pick the target version from the [Mihomo releases page](https://github.com/MetaCubeX/mihomo/releases) (tags look like `v1.19.0`). Skim the release notes for config changes: a newer Mihomo may reject or reinterpret fields in your `config.yaml`, and because the workspace is fail-closed, a Mihomo that fails to start means **no network at all** inside the container.

There are two ways to upgrade:

| | Method A: rebuild the image | Method B: swap the binary in place |
| --- | --- | --- |
| Persistence | Permanent | Lost when the container is recreated |
| Recreates the container | Yes | No |
| `apt-get`-installed system packages | Lost (home directory is kept) | Kept |
| Typical use | Long-term upgrade | Quick try-out, or you can't recreate right now |

## Method A: Rebuild the Image (Recommended)

1. Change the default version in **both** Dockerfiles so CLI and desktop modes stay in sync:

   ```dockerfile
   ARG MIHOMO_VERSION=v1.19.0
   ```

2. Rebuild and recreate the container:

   ```bash
   docker compose up -d --build
   ```

   Changing the `ARG` value invalidates the build cache for the download step, so the new binary is fetched. The download happens on the host, so it does not depend on the container's proxy chain.

3. Verify (see [Verifying the upgrade](#verifying-the-upgrade)).

The home directory in the `workspace_home` volume survives the recreate, but system packages you installed with `sudo apt-get install` do not. Bake those into the Dockerfile if you need them every time.

> You can also try a version without editing the Dockerfile: `docker compose build --build-arg MIHOMO_VERSION=v1.19.0 && docker compose up -d`. The next plain `docker compose up -d --build` reverts to the version in the Dockerfile, so edit the Dockerfile once you decide to keep it.

## Method B: Swap the Binary in Place

This replaces the binary inside the running container and restarts Mihomo with `reload-proxy`. Nothing is recreated, but the change disappears the next time the container is recreated (for example after `docker compose up -d --build`); use Method A to make it permanent.

Open a root shell in the container:

```bash
docker compose exec workspace bash
```

(From inside the workspace you can use `sudo -i` instead.)

1. Download the new binary. The download goes through the current Mihomo, so the proxy must be working at this point:

   ```bash
   VERSION=v1.19.0
   case "$(uname -m)" in
     x86_64)  ARCH=amd64 ;;
     aarch64) ARCH=arm64 ;;
     *) echo "unsupported arch: $(uname -m)"; exit 1 ;;
   esac
   mkdir -p /tmp/mihomo-new && cd /tmp/mihomo-new
   curl -fL -o mihomo.gz \
     "https://github.com/MetaCubeX/mihomo/releases/download/${VERSION}/mihomo-linux-${ARCH}-${VERSION}.gz"
   gunzip -f mihomo.gz && chmod +x mihomo
   ```

2. Check the new binary runs and accepts your current config **before** replacing anything:

   ```bash
   ./mihomo -v
   ./mihomo -t -d /root/.config/mihomo
   ```

   `-t` only tests the configuration and exits. If it reports errors, fix `config.yaml` first (or stay on the old version).

3. Back up the old binary, install the new one, and restart Mihomo:

   ```bash
   cp /usr/local/bin/mihomo /usr/local/bin/mihomo.bak
   install -m 755 ./mihomo /usr/local/bin/mihomo
   reload-proxy
   ```

   `install` replaces the file instead of writing into it, so it works even while the old Mihomo is still running.

### Rolling Back

If Mihomo does not come back up, the killswitch blocks all traffic, so you cannot download anything else. Restore the backup, which needs no network:

```bash
install -m 755 /usr/local/bin/mihomo.bak /usr/local/bin/mihomo
reload-proxy
```

Recreating the container (`docker compose up -d --force-recreate`) also restores the version baked into the image.

## Verifying the Upgrade

```bash
docker compose exec workspace mihomo -v
docker compose exec workspace curl -4 --max-time 15 https://ifconfig.me
```

The first command should print the new version, the second your proxy exit IP. If the exit IP check fails, look at the Mihomo log, which is written to `logs/mihomo.log` on the host (`/var/log/mihomo.log` in the container):

```bash
tail -n 50 logs/mihomo.log
```

## Notes

- On older x86-64 CPUs, the default `amd64` build may fail with `illegal instruction`. Mihomo also publishes an `amd64-compatible` build (`mihomo-linux-amd64-compatible-<version>.gz`); use that file name in the download URL instead (in Method A, edit the `wget` URL in the Dockerfiles).
- Only the Mihomo binary changes. The allowlist and killswitch logic still come from `config.yaml` → `tun.route-exclude-address`, so no other files need to be touched.
