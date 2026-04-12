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
