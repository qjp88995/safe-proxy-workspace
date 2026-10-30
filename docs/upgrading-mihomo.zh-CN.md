# 升级 Mihomo

Mihomo 二进制在构建镜像时就已打包进去。版本由 `Dockerfile` 和 `Dockerfile.desktop` 中的构建参数 `MIHOMO_VERSION` 决定，二进制位于 `/usr/local/bin/mihomo`。

先在 [Mihomo 发布页](https://github.com/MetaCubeX/mihomo/releases) 选定目标版本（标签形如 `v1.19.0`），并浏览一下发布说明中的配置变更：新版 Mihomo 可能拒绝或改变 `config.yaml` 中某些字段的含义。由于工作环境是 fail-closed 的，Mihomo 启动失败就意味着容器内**完全断网**。

升级有两种方式：

| | 方式 A：重建镜像 | 方式 B：原地替换二进制 |
| --- | --- | --- |
| 持久性 | 永久生效 | 重建容器后失效 |
| 是否重建容器 | 是 | 否 |
| 通过 `apt-get` 安装的系统软件 | 丢失（home 目录保留） | 保留 |
| 适用场景 | 长期升级 | 快速试用新版，或暂时不便重建容器 |

## 方式 A：重建镜像（推荐）

1. 修改**两个** Dockerfile 中的默认版本，保持 CLI 与桌面模式一致：

   ```dockerfile
   ARG MIHOMO_VERSION=v1.19.0
   ```

2. 重新构建并重建容器：

   ```bash
   docker compose up -d --build
   ```

   修改 `ARG` 的值会使下载步骤的构建缓存失效，从而拉取新的二进制。下载发生在宿主机上，不依赖容器内的代理链。

3. 验证（见[验证升级结果](#验证升级结果)）。

`workspace_home` volume 中的 home 目录在重建后仍然保留，但通过 `sudo apt-get install` 安装的系统软件会丢失。如果某个软件每次都要用，请写进 Dockerfile。

> 也可以不改 Dockerfile 先试用某个版本：`docker compose build --build-arg MIHOMO_VERSION=v1.19.0 && docker compose up -d`。但下一次普通的 `docker compose up -d --build` 会回到 Dockerfile 中的版本，所以确定要保留时请修改 Dockerfile。

## 方式 B：原地替换二进制

这种方式直接替换运行中容器里的二进制，并用 `reload-proxy` 重启 Mihomo。不会重建容器，但下次重建容器（例如执行 `docker compose up -d --build`）后改动就会消失；要永久生效请使用方式 A。

以 root 身份进入容器：

```bash
docker compose exec workspace bash
```

（也可以在工作环境内执行 `sudo -i`。）

1. 下载新的二进制。下载流量会经过当前的 Mihomo，所以此时代理必须是通的：

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

2. 在替换任何东西**之前**，确认新二进制能运行并且接受当前配置：

   ```bash
   ./mihomo -v
   ./mihomo -t -d /root/.config/mihomo
   ```

   `-t` 只测试配置然后退出。如果报错，先修正 `config.yaml`（或继续使用旧版本）。

3. 备份旧二进制，安装新二进制，然后重启 Mihomo：

   ```bash
   cp /usr/local/bin/mihomo /usr/local/bin/mihomo.bak
   install -m 755 ./mihomo /usr/local/bin/mihomo
   reload-proxy
   ```

   `install` 是替换文件而不是向原文件写入，因此旧 Mihomo 仍在运行时也能正常执行。

### 回滚

如果 Mihomo 没能重新启动，killswitch 会拦截所有流量，此时无法再下载任何东西。直接恢复备份即可，这一步不需要网络：

```bash
install -m 755 /usr/local/bin/mihomo.bak /usr/local/bin/mihomo
reload-proxy
```

重建容器（`docker compose up -d --force-recreate`）同样会恢复到镜像中打包的版本。

## 验证升级结果

```bash
docker compose exec workspace mihomo -v
docker compose exec workspace curl -4 --max-time 15 https://ifconfig.me
```

第一条命令应输出新版本号，第二条应输出代理出口 IP。如果出口 IP 检查失败，请查看 Mihomo 日志，它写在宿主机的 `logs/mihomo.log`（容器内为 `/var/log/mihomo.log`）：

```bash
tail -n 50 logs/mihomo.log
```

## 注意事项

- 在较老的 x86-64 CPU 上，默认的 `amd64` 构建可能报 `illegal instruction`。Mihomo 还提供 `amd64-compatible` 构建（`mihomo-linux-amd64-compatible-<version>.gz`），把下载 URL 中的文件名换成它即可（方式 A 需要修改 Dockerfile 里的 `wget` URL）。
- 升级只改变 Mihomo 二进制本身。白名单与 killswitch 逻辑仍然来自 `config.yaml` → `tun.route-exclude-address`，不需要改动其他文件。
