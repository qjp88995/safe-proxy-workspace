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

The mapped user's home directory is persisted in the Docker volume `workspace_home`, so changes under `~` survive container rebuilds. System packages installed with `sudo apt-get install ...` still belong to the image filesystem; if you need them every time, prefer baking them into the relevant Dockerfile.

## Fix UTF-8 Locale In Desktop Terminals

If a terminal opened inside the VNC desktop reports `ANSI_X3.4-1968` or `POSIX`, it is running in an ASCII locale instead of UTF-8. TUI applications may then render Chinese text or emoji as garbled characters.

Check the current locale:

```bash
locale
python3 -c 'import locale; print(locale.getpreferredencoding(False))'
```

Install locales and generate a UTF-8 locale if needed:

```bash
sudo apt-get install -y locales
sudo locale-gen en_US.UTF-8
```

For the current shell, test with:

```bash
export LANG=C.UTF-8
export LC_ALL=C.UTF-8
```

To make it persistent for the workspace user without disabling the default colored prompt from `./enter-workspace.sh`, write it to `~/.profile` instead of `~/.bashrc`:

```bash
printf '\nexport LANG=C.UTF-8\nexport LC_ALL=C.UTF-8\n' >> ~/.profile
```

Then open a new terminal in the VNC desktop and confirm that the preferred encoding is `UTF-8`.

## Google Chrome

On `amd64`, `Dockerfile.desktop` already preinstalls Google Chrome in desktop/VNC mode. Because the workspace home directory is persisted, Chrome keeps its profile, cookies, and login state across container rebuilds.

If you are building the desktop image for another architecture, Chrome is not preinstalled by this repository.
