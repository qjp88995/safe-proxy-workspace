# 常用软件安装

先进入工作环境：

```bash
./enter-workspace.sh
```

然后先更新软件源并升级已安装的软件包：

```bash
sudo apt-get update
sudo apt-get dist-upgrade
```

如需设置时区，执行：

```bash
sudo dpkg-reconfigure tzdata
```

映射用户的 home 目录会持久化到 Docker volume `workspace_home`，因此 `~` 下的改动在重建容器后仍然保留。相对地，使用 `sudo apt-get install ...` 安装到系统层的软件仍然属于镜像文件系统；如果某个软件每次都要用，最好直接写进对应的 Dockerfile。

修改代理白名单（`config.yaml` 中的 `tun.route-exclude-address`）不再需要重建容器。编辑完 `config.yaml` 后执行 `docker compose exec workspace reload-proxy`（或在工作环境内执行 `sudo reload-proxy`）即可——它会重新加载 killswitch / 路由绕行规则并原地重启 Mihomo，本次会话中通过 `apt-get` 安装的软件不会丢失。

## 当代理节点是域名时

订阅配置常把 `proxies[*].server` 写成**域名**而非 IP。直接这样用是不行的：`tun.route-exclude-address` 是喂给 iptables killswitch 与路由绕行的唯一来源，而它只能是 IP 或 CIDR。iptables 和 `ip rule` 无法匹配域名，因此域名条目会被静默跳过，killswitch 会拦掉 Mihomo 到上游节点的连接，`reload-proxy` 随即报告网络不通（fail-closed）。

从下面两种方案里选一种。两种方案里 `route-exclude-address` **都必须**是 IP。

先把域名解析成 IP（例如 `getent hosts your.domain.com` 或 `nslookup your.domain.com`），假设是 `1.2.3.4`。

**方案 A —— 直接用 IP（最省事）。** 两处都填 IP：

```yaml
proxies:
  - name: "..."
    server: 1.2.3.4          # 用 IP 替代域名
tun:
  route-exclude-address:
    - 1.2.3.4/32
```

**方案 B —— 保留域名（与订阅对齐）。** `server` 保留域名，并用 `hosts` 把它钉到 IP，让 Mihomo 本地解析、而不发出 DNS 查询（DNS 查询会被 killswitch 拦掉）：

```yaml
hosts:
  "your.domain.com": 1.2.3.4

proxies:
  - name: "..."
    server: your.domain.com  # 保留域名，由 hosts 解析

tun:
  route-exclude-address:
    - 1.2.3.4/32             # 始终是 IP
```

`hosts` 这个键只有 Mihomo 会读；项目脚本从不解析它，因此**无需改动任何代码**——编辑 `config.yaml` 并执行 `reload-proxy` 就够了。

> **注意：** `hosts` 里的 IP 和 `route-exclude-address` 里的 IP 都是硬编码的。域名之所以用域名，往往正是因为其 IP 会变；一旦节点 IP 漂移，这两行就都会过期、导致断网。遇到这种情况，重新解析域名、同步更新这两处 IP，再执行一次 `reload-proxy` 即可。

## UTF-8 编码

镜像现在会在系统级默认生成并启用 `en_US.UTF-8`，因此你在 VNC 桌面里打开终端后，默认就应该已经是 UTF-8。

可以这样检查：

```bash
locale
python3 -c 'import locale; print(locale.getpreferredencoding(False))'
```

如果你仍然看到 `ANSI_X3.4-1968` 或 `POSIX`，通常说明你还在使用旧容器，需要重建：

```bash
docker compose up -d --build
```

## Google Chrome

在 `amd64` 上，桌面 / VNC 模式对应的 `Dockerfile.desktop` 已经直接预装了 Google Chrome。由于工作用户的 home 目录会持久化，Chrome 的 profile、Cookie 和登录状态也会跨容器重建保留。

如果你构建的是其他架构的桌面镜像，这个仓库当前不会自动预装 Chrome。
