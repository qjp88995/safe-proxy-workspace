# 伴随服务

工作容器运行时会启用 fail-closed 的 iptables killswitch。任何通过 `network_mode: "service:workspace"` 加入其网络命名空间的 Docker 服务，都可以通过 loopback 与工作容器互相通信——killswitch 本身已经放行了 `lo` 流量，因此无需修改现有镜像或 entrypoint。

这个模式适合数据库、缓存等只需要在工作容器内部访问、不需要暴露到外网的本地服务。

## 原理

- postgres（或其他服务）容器加入 workspace 的网络命名空间，而不是 Docker 默认的 bridge 网络。
- 两个容器共享同一个 loopback 接口，因此在工作容器内访问 `localhost:5432` 就能直接连到 postgres。
- killswitch 规则 `-A OUTPUT -o lo -j ACCEPT` 已经覆盖了这条路径。
- postgres 在正常使用中不会主动发起出站连接，所以其他出站流量的 DROP 默认规则不会造成影响。

## PostgreSQL 示例

在 `docker-compose.yml` 中追加以下服务配置：

```yaml
services:
  workspace:
    # ... 现有 workspace 配置，不需要修改 ...

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

在工作容器内连接：

```bash
psql -h localhost -U app -d appdb
```

### 将端口暴露给宿主机

由于 postgres 共享 workspace 的网络命名空间，端口映射必须声明在 `workspace` 服务上，而不是 `postgres` 服务上：

```yaml
services:
  workspace:
    ports:
      - "127.0.0.1:5432:5432"
      # ... 其他已有的端口映射 ...
```

## 注意事项

- **`depends_on` 是必须的。** workspace 容器必须先运行并完成网络命名空间初始化，postgres 才能启动。
- **不需要修改镜像。** 现有的 `Dockerfile` 和 `entrypoint.sh` 无需任何改动。
- **伴随服务的出站流量同样受 killswitch 约束。** 所有共享该网络命名空间的服务都遵循同一套 iptables 规则。对于数据库这类纯本地服务，这不会有任何影响。
- **每个伴随服务的文件系统是独立的。** 共享的只有网络命名空间，各容器的挂载、环境变量和 `/etc/resolv.conf` 仍然相互独立。
