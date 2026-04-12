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

## 修复桌面终端的 UTF-8 编码

如果你在 VNC 桌面里打开终端后看到 `ANSI_X3.4-1968` 或 `POSIX`，说明当前终端实际上跑在 ASCII locale 下，不是 UTF-8。这样在 TUI 程序里显示中文或 emoji 时就很容易出现乱码。

先检查当前 locale：

```bash
locale
python3 -c 'import locale; print(locale.getpreferredencoding(False))'
```

如有需要，先安装 locales 并生成 UTF-8 locale：

```bash
sudo apt-get install -y locales
sudo locale-gen en_US.UTF-8
```

当前 shell 可以先临时测试：

```bash
export LANG=C.UTF-8
export LC_ALL=C.UTF-8
```

如果确认有效，再把它持久化到工作用户的 shell 配置里。这里建议写到 `~/.profile`，不要写进 `~/.bashrc`，否则会让 `./enter-workspace.sh` 默认的彩色提示符失效：

```bash
printf '\nexport LANG=C.UTF-8\nexport LC_ALL=C.UTF-8\n' >> ~/.profile
```

然后重新打开一个 VNC 终端，确认默认编码已经变成 `UTF-8`。

## Google Chrome

在 `amd64` 上，桌面 / VNC 模式对应的 `Dockerfile.desktop` 已经直接预装了 Google Chrome。由于工作用户的 home 目录会持久化，Chrome 的 profile、Cookie 和登录状态也会跨容器重建保留。

如果你构建的是其他架构的桌面镜像，这个仓库当前不会自动预装 Chrome。
