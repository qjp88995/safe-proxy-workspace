# Installing Common Software

Enter the workspace first:

```bash
./enter-workspace.sh
```

Then update the package index and upgrade installed packages:

```bash
sudo apt-get update
sudo apt-get dist-upgrade
```

If you need to configure the timezone, run:

```bash
sudo dpkg-reconfigure tzdata
```

## Install Google Chrome

Download the Debian package:

```bash
wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
```

Install it with `dpkg`:

```bash
sudo dpkg -i google-chrome-stable_current_amd64.deb
```

If `dpkg` reports missing dependencies, fix them with:

```bash
sudo apt-get install -f
```
