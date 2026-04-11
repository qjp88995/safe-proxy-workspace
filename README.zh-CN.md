# safe-proxy-workspace

[English README](README.md)

一个基于 Mihomo 的 fail-closed Docker 工作容器。容器内流量要么通过你的 SS relay chain 转发，要么被直接阻断。

## 这个项目做什么

- 提供一个可长期运行的工作容器，内部集成 Mihomo
- 使用基于 TUN 的 relay chain 接管容器出站流量
- 只允许直连代理节点本身
- 当代理链不可用时，阻断其他所有出站流量
- 让挂载目录中的文件尽量保持与宿主机一致的 UID/GID

## 运行要求

- Linux 宿主机
- Docker Engine 和 Docker Compose
- 宿主机存在 `/dev/net/tun`
- SS 节点可连通

## 快速开始

1. 复制本地配置文件：

```bash
cp .env.example .env
cp config.example.yaml config.yaml
```

2. 编辑 `config.yaml`：

- 把样例 SS 服务器、端口、加密方式、密码替换成真实值
- 保持 `tun.route-exclude-address` 为代理节点 IP
- 如果你没有同步修改 `.env`，就不要改 `device: Mihomo`

3. 编辑 `.env`：

- 把 `DIRECT_ALLOWLIST_TCP` 和 `DIRECT_ALLOWLIST_UDP` 设置成与 `config.yaml` 中相同的代理 `IP:PORT`
- 如果要挂载别的工作目录，修改 `WORKSPACE_MOUNT`

4. 启动容器：

```bash
docker compose up -d
```

5. 进入工作环境：

```bash
./enter-workspace.sh
```

6. 检查出口 IP：

```bash
docker compose exec workspace curl -4 --max-time 15 https://ifconfig.me
```

## 挂载其他工作目录

```bash
WORKSPACE_MOUNT=/your/project/path docker compose up -d
./enter-workspace.sh
```

在 `/workspace` 下创建的文件会尽量使用与宿主机挂载目录一致的 UID/GID。

## 使用预构建镜像

带 tag 的版本会发布到 GHCR。

拉取某个发布版本：

```bash
docker pull ghcr.io/qjp88995/safe-proxy-workspace:v0.0.1
```

或者直接拉取最新发布镜像：

```bash
docker pull ghcr.io/qjp88995/safe-proxy-workspace:latest
```

如果希望 Compose 直接使用远程镜像，可以在 `.env` 中设置：

```bash
IMAGE_NAME=ghcr.io/qjp88995/safe-proxy-workspace:latest
```

然后执行：

```bash
docker compose pull
docker compose up -d
```

## 安全模型

这个项目的目标是 fail-closed：

- 代理节点本身允许直连
- 其他所有出站流量都必须经过 `Mihomo` TUN
- 代理链失效时，容器会失去外网能力，而不是回落到宿主机真实 IP
- 默认禁用 IPv6，以减少泄漏路径

下面两处配置必须保持一致：

1. `.env` 中的 `DIRECT_ALLOWLIST_TCP` 和 `DIRECT_ALLOWLIST_UDP`
2. `config.yaml` 中的 `tun.route-exclude-address`

它们都必须描述同一组代理节点。

## 常用命令

启动或重建：

```bash
docker compose up -d --build
```

进入工作环境：

```bash
./enter-workspace.sh
```

查看日志：

```bash
docker compose logs -f workspace
```

停止容器：

```bash
docker compose down
```

## GitHub Actions

`.github/workflows/docker-image.yaml` 会在你 push `v0.0.1` 这类 tag 时构建并推送镜像到 GHCR。

同时也支持通过 `workflow_dispatch` 手动触发。

## 仓库结构

| 文件 | 用途 |
| --- | --- |
| `Dockerfile` | 构建镜像 |
| `docker-compose.yml` | 运行工作容器 |
| `entrypoint.sh` | 配置 kill switch、策略路由、DNS 和 UID/GID 映射 |
| `enter-workspace.sh` | 以映射后的工作用户进入容器 |
| `config.example.yaml` | Mihomo 配置样例 |
| `.env.example` | Compose 环境变量样例 |

## 不要提交的文件

- `.env`
- `config.yaml`
- `logs/`
