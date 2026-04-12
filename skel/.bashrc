# ~/.bashrc: executed by bash(1) for non-login shells.

case $- in
  *i*) ;;
  *) return ;;
esac

if [ -f /etc/bash.bashrc ]; then
  . /etc/bash.bashrc
fi

if command -v dircolors >/dev/null 2>&1; then
  eval "$(dircolors -b 2>/dev/null || true)"
  alias ls='ls --color=auto'
  alias grep='grep --color=auto'
  alias fgrep='fgrep --color=auto'
  alias egrep='egrep --color=auto'
fi

color_prompt=
case "${TERM:-}" in
  *color*|xterm*|screen*|tmux*|rxvt*|linux*)
    color_prompt=yes
    ;;
esac

if [ "${color_prompt}" = yes ]; then
  PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
else
  PS1='${debian_chroot:+($debian_chroot)}\u@\h:\w\$ '
fi

unset color_prompt
