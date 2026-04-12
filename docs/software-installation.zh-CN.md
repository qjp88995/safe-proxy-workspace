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
