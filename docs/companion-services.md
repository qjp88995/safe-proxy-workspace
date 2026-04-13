# Companion Services

The workspace container runs with a fail-closed iptables killswitch. Any Docker service that joins its network namespace via `network_mode: "service:workspace"` shares that namespace and can communicate with the workspace over loopback — the killswitch already allows `lo` traffic, so no changes to the existing image or entrypoint are needed.

This pattern is useful for databases, caches, and other local-only services that you want accessible inside the workspace without exposing them to external networks.

## How it works

- The postgres (or any other) container joins the workspace's network namespace instead of Docker's default bridge.
- Both containers share the same loopback interface, so `localhost:5432` inside the workspace reaches postgres directly.
- The killswitch's `-A OUTPUT -o lo -j ACCEPT` rule covers this path.
- Postgres does not initiate outbound connections in normal operation, so the DROP default on all other outbound traffic does not interfere.

## PostgreSQL example

Add the following service to `docker-compose.yml`:

```yaml
services:
  workspace:
    # ... existing workspace config, unchanged ...

  postgres:
    image: postgres:16
    network_mode: "service:workspace"
    depends_on:
      workspace:
        condition: service_started
    environment:
      POSTGRES_USER: app
      POSTGRES_PASSWORD: secret
      POSTGRES_DB: appdb
    volumes:
      - pgdata:/var/lib/postgresql/data
    restart: unless-stopped

volumes:
  pgdata:
```

Connect from inside the workspace:

```bash
psql -h localhost -U app -d appdb
```

### Exposing the port to the host

Because postgres shares the workspace's network namespace, port mappings must be declared on the `workspace` service, not on `postgres`:

```yaml
services:
  workspace:
    ports:
      - "127.0.0.1:5432:5432"
      # ... other existing ports ...
```

## Notes

- **`depends_on` is required.** The workspace container must be running and its network namespace fully initialized before postgres starts.
- **No image changes needed.** The existing `Dockerfile` and `entrypoint.sh` require no modifications.
- **Outbound traffic from companion services is also killswitched.** Any service sharing the network namespace is subject to the same iptables rules. This is fine for local-only services like databases.
- **Each companion service keeps its own filesystem.** Only the network namespace is shared; mounts, environment variables, and `/etc/resolv.conf` remain independent per container.
