# safe-proxy-workspace

A fail-closed Docker workspace powered by Mihomo, routing all container traffic through an SS relay chain or blocking it entirely.

## 特性

- **Fail-closed**：容器内除代理节点外，其余出站流量只能走 TUN，否则直接被 `iptables` 丢弃
- **Relay 链路**：支持两跳 SS 中继
- **长期工作容器**：单一 `workspace` 服务可常驻运行，挂载目录会自动匹配宿主机 UID/GID，避免产出 `root:root` 文件
- **公开仓库友好**：真实配置和 `.env` 默认不进仓库，仓库里只保留样例文件

## 文件说明

| 文件 | 用途 |
| --- | --- |
| `Dockerfile` | 构建镜像 |
| `.github/workflows/docker-image.yaml` | GitHub Actions 自动构建镜像 |
| `docker-compose.yml` | 运行长期工作容器 |
| `config.example.yaml` | `mihomo` 配置样例 |
| `config.yaml` | 本地实际配置，已被 `.gitignore` 忽略 |
| `.env.example` | Compose 环境变量样例 |
| `.env` | 本地实际环境变量，已被 `.gitignore` 忽略 |
| `entrypoint.sh` | 启动 kill switch、策略路由和工作用户映射 |
| `enter-workspace.sh` | 进入长期工作容器的辅助脚本 |

## 初始化

先复制样例文件：

```bash
cp .env.example .env
cp config.example.yaml config.yaml
```

然后编辑 `.env`：

- 把 `DIRECT_ALLOWLIST_TCP` / `DIRECT_ALLOWLIST_UDP` 改成你的代理节点 `IP:PORT`
- 如需长期挂载其他目录，修改 `WORKSPACE_MOUNT`

再编辑 `config.yaml`：

- 填入真实代理节点和密码
- 保证 `tun.route-exclude-address` 与 `.env` 中的代理节点 IP 一致

## 启动容器

```bash
docker compose up -d
```

检查出口 IP：

```bash
docker compose exec workspace curl -4 --max-time 15 https://ifconfig.me
```

## GitHub Actions 自动构建镜像

仓库内置了 `.github/workflows/docker-image.yaml`：

- `push` tag（如 `v1.0.0`）：构建并推送 GHCR 镜像
- `workflow_dispatch`：允许你在 GitHub Actions 页面手动触发一次构建

如果你准备把镜像发布到 GHCR，确保仓库启用了 GitHub Packages 权限即可。这个 workflow 默认使用 `GITHUB_TOKEN` 登录 GHCR，不需要额外的 registry secret。

构建完成后，也可以直接拉取预构建镜像：

```bash
docker pull ghcr.io/qjp88995/safe-proxy-workspace:latest
docker pull ghcr.io/qjp88995/safe-proxy-workspace:v1.0.0
```

## 进入工作环境

```bash
docker compose up -d
./enter-workspace.sh
```

如果要挂载别的项目目录：

```bash
WORKSPACE_MOUNT=/your/project/path docker compose up -d
./enter-workspace.sh
```

进入后，在 `/workspace` 内创建的文件会尽量保持与宿主机挂载目录一致的 UID/GID。

## 安全模型

当前设计目标是：

- **代理节点本身可以直连**
- **其他所有外连流量必须走 `Mihomo` TUN**
- **如果代理链断开，容器直接失去外网能力，而不是回落到宿主机真实 IP**

要保持这个特性，下面两处必须同步维护：

1. `.env` 中的 `DIRECT_ALLOWLIST_TCP` / `DIRECT_ALLOWLIST_UDP`
2. `config.yaml` 中的 `tun.route-exclude-address`

它们都应该指向同一组代理节点。

## 建议提交到 GitHub 的文件

- `Dockerfile`
- `docker-compose.yml`
- `.github/workflows/docker-image.yaml`
- `entrypoint.sh`
- `enter-workspace.sh`
- `config.example.yaml`
- `.env.example`
- `.gitignore`
- `README.md`

不要提交：

- `.env`
- `config.yaml`
- `logs/`
