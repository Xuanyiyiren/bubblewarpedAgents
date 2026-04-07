#!/usr/bin/env bash

SCRIPT_PATH="$(realpath "$0")"

SYSTEM_BINDS="
  --ro-bind /usr /usr
  --ro-bind /lib /lib
  --ro-bind /lib64 /lib64
  --ro-bind /bin /bin
  --ro-bind /etc/resolv.conf /etc/resolv.conf
  --ro-bind /etc/hosts /etc/hosts
  --ro-bind /etc/ssl /etc/ssl
  --ro-bind /etc/ca-certificates /etc/ca-certificates
  --ro-bind /etc/pkcs11 /etc/pkcs11
  --ro-bind /etc/passwd /etc/passwd
  --ro-bind /etc/group /etc/group
"

# These overrides must come after the broader system binds they mask.
OVERRIDE_BINDS="
  --ro-bind /dev/null /usr/bin/sudo
"

# These paths might not exist.
HOME_BINDS=""
[ -d "$HOME/.local" ] && HOME_BINDS="$HOME_BINDS --ro-bind $HOME/.local $HOME/.local"
[ -d "$HOME/.npm" ] && HOME_BINDS="$HOME_BINDS --ro-bind $HOME/.npm $HOME/.npm"
[ -d "$HOME/.npm-global" ] && HOME_BINDS="$HOME_BINDS --ro-bind $HOME/.npm-global $HOME/.npm-global"
# [ -d "$HOME/.agents" ] && HOME_BINDS="$HOME_BINDS --ro-bind $HOME/.agents $HOME/.agents"
[ -d "$HOME/.codex" ] && HOME_BINDS="$HOME_BINDS --bind $HOME/.codex $HOME/.codex"
[ -d "$HOME/superpowers/skills" ] && HOME_BINDS="$HOME_BINDS --ro-bind $HOME/superpowers/skills $HOME/superpowers/skills"

bwrap \
  $SYSTEM_BINDS \
  $OVERRIDE_BINDS \
  $HOME_BINDS \
  --bind "$PWD" "$PWD" \
  --ro-bind "$SCRIPT_PATH" "$SCRIPT_PATH" \
  --proc /proc \
  --dev /dev \
  --tmpfs /tmp \
  --share-net \
  --unshare-pid \
  --die-with-parent \
  --chdir "$PWD" \
  codex --dangerously-bypass-approvals-and-sandbox "$@"
