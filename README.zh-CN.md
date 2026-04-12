# safe-proxy-workspace

[English README](README.md)

一个基于 Mihomo 的 fail-closed Docker 工作容器。容器内流量要么通过你的 SS relay chain 转发，要么被直接阻断。

## 这个项目做什么

- 提供一个可长期运行的工作容器，内部集成 Mihomo
- 使用基于 TUN 的 relay chain 接管容器出站流量
- 只允许直连代理节点本身
- 当代理链不可用时，阻断其他所有出站流量
- 给用户一个正常的 home 目录，并把宿主机工作目录挂载到 `~/workspace`
- 用 Docker volume 持久化映射用户的 home 目录，避免容器重建后丢失用户环境

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
- 如果想修改容器内用户名和 home 路径名，设置 `WORKSPACE_USER`

4. 启动容器：

```bash
docker compose up -d
```

5. 进入工作环境：

```bash
./enter-workspace.sh
```

这个辅助脚本会保留映射后用户的 `HOME` 和 shell 环境，并默认进入 `~/workspace`，因此交互式 Bash 的彩色提示符与颜色输出会正常工作。

在容器里，映射出来的工作用户拥有正常的 home 目录 `/home/$WORKSPACE_USER`，而宿主机工作目录会挂载到 `~/workspace`。这个 home 目录会持久化到 Docker volume `workspace_home`，所以 shell 配置、浏览器资料和用户级工具在 `docker compose up --build` 或重建容器后仍然保留。如果你想修改容器内用户名和 home 目录名，只需要调整 `.env` 里的 `WORKSPACE_USER`。这个用户可以像普通 Ubuntu 用户一样使用免密码 `sudo` 安装软件和管理自己的工具。

常用软件安装方式见[常用软件安装](docs/software-installation.zh-CN.md)。

6. 检查出口 IP：

```bash
docker compose exec workspace curl -4 --max-time 15 https://ifconfig.me
```

## 在 CLI 镜像和桌面镜像之间切换

Compose 现在只管理一个 `workspace` 服务。你可以通过修改 `.env`，把它切换成 CLI 镜像或者桌面 / VNC 镜像。

CLI 模式：

```bash
IMAGE_NAME=safe-proxy-workspace:latest
DOCKERFILE=Dockerfile
DESKTOP_MODE=0
```

桌面 / VNC 模式：

```bash
IMAGE_NAME=safe-proxy-workspace-desktop:latest
DOCKERFILE=Dockerfile.desktop
DESKTOP_MODE=1
VNC_PASSWORD=replace-this-before-use
DESKTOP_SHM_SIZE=2gb
```

桌面容器还会额外添加 `SYS_ADMIN`，这样 Google Chrome 这类图形浏览器在 Docker 里也能启用 Linux sandbox。若你之前是用 `--no-sandbox` 启动 Chrome，重建容器后请把这个参数去掉。
在 `amd64` 上，桌面镜像还会直接预装 Google Chrome。由于用户 home 目录会持久化，Chrome 的登录状态和个人资料也会跨重建保留。

然后像平时一样启动同一个服务：

```bash
docker compose up -d
```

在桌面模式下，默认用 VNC 客户端连接 `127.0.0.1:5901`。默认会把端口只绑定到宿主机 `127.0.0.1`，除非你主动修改 `DESKTOP_VNC_BIND`，否则不会直接暴露到所有网卡。

桌面容器默认还会放大 `/dev/shm`，因为 Google Chrome 这类图形浏览器在 VNC 容器环境里如果继续使用 Docker 默认的 64 MB 共享内存，常见表现就是打开网页时直接崩溃。若需要调整，可以修改 `DESKTOP_SHM_SIZE`。

## 挂载其他工作目录

```bash
WORKSPACE_MOUNT=/your/project/path docker compose up -d
./enter-workspace.sh
```

在 `~/workspace` 下创建的文件会尽量使用与宿主机目录一致的 UID/GID。

## 持久化 home 目录

映射用户的 home 目录会存放在 Docker volume `workspace_home` 中。

因此下面这些内容在重建容器后仍会保留：

- `~/.bashrc`、`~/.profile` 等 shell 启动文件
- `~/.config/google-chrome` 这类浏览器数据
- `~/.npm`、`~/.local`、`~/.config` 这类用户级工具状态

如果你想把这些持久化数据一并清空，从一个全新的 home 开始：

```bash
docker compose down -v
```

## 使用预构建镜像

带 tag 的版本会发布到 GHCR。

如果你想给最终用户提供“只运行、不本地构建”的入口，直接使用 [runtime](/home/calf/projects/safe-proxy-workspace/runtime/README.md:1) 目录里的内容。这种方式本地只需要：

- `runtime/docker-compose.yml`
- `.env`
- `config.yaml`
- `runtime/enter-workspace.sh`

拉取某个发布版本：

```bash
docker pull ghcr.io/qjp88995/safe-proxy-workspace:v0.0.1
```

或者直接拉取最新发布镜像：

```bash
docker pull ghcr.io/qjp88995/safe-proxy-workspace:latest
```

桌面 / VNC 版本镜像：

```bash
docker pull ghcr.io/qjp88995/safe-proxy-workspace-desktop:latest
```

如果希望 Compose 直接使用远程镜像，可以在 `.env` 中设置：

```bash
IMAGE_NAME=ghcr.io/qjp88995/safe-proxy-workspace:latest
DOCKERFILE=Dockerfile
DESKTOP_MODE=0
```

或者把同一个 `workspace` 服务切换到桌面镜像：

```bash
IMAGE_NAME=ghcr.io/qjp88995/safe-proxy-workspace-desktop:latest
DOCKERFILE=Dockerfile.desktop
DESKTOP_MODE=1
VNC_PASSWORD=replace-this-before-use
```

然后执行：

```bash
cd runtime
docker compose pull
docker compose up -d
```

如果你会在桌面模式里使用 Google Chrome，更新后请重建容器，这样浏览器就能尽量以启用 sandbox 的方式启动，不再弹出 `--no-sandbox` 的提示。在 `amd64` 上，桌面镜像已经内置 Chrome。

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
| `Dockerfile.desktop` | 构建预装桌面 / VNC 镜像 |
| `docker-compose.yml` | 运行单一 workspace 容器并把宿主机项目挂载到 `~/workspace` |
| `runtime/` | 面向预构建镜像的 runtime-only 目录 |
| `entrypoint.sh` | 配置 kill switch、策略路由、DNS 和 UID/GID 映射 |
| `desktop-session.sh` | 在 TigerVNC 中启动 XFCE 会话 |
| `enter-workspace.sh` | 以映射后的工作用户进入容器 |
| `skel/` | 新建工作用户 home 时使用的默认 shell 启动文件 |
| `config.example.yaml` | Mihomo 配置样例 |
| `.env.example` | Compose 环境变量样例 |

## 不要提交的文件

- `.env`
- `config.yaml`
- `logs/`
