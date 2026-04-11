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

## 安装 Google Chrome

先下载 Debian 安装包：

```bash
wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
```

使用 `dpkg` 安装：

```bash
sudo dpkg -i google-chrome-stable_current_amd64.deb
```

如果 `dpkg` 提示缺少依赖，再执行：

```bash
sudo apt-get install -f
```
