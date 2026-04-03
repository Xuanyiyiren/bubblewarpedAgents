#!/usr/bin/env bash

# Optional paths - only bind if they exist
OPTIONAL_BINDS=""
# [ -d "$HOME/.nvm" ] && OPTIONAL_BINDS="$OPTIONAL_BINDS --ro-bind $HOME/.nvm $HOME/.nvm"
# [ -d "$HOME/.config/git" ] && OPTIONAL_BINDS="$OPTIONAL_BINDS --ro-bind $HOME/.config/git $HOME/.config/git"
# [ -d "$HOME/.config/gh" ] && OPTIONAL_BINDS="$OPTIONAL_BINDS --ro-bind $HOME/.config/gh $HOME/.config/gh"

# These paths might not exist
EXTRA_BINDS=""
[ -d "$HOME/.local" ] && EXTRA_BINDS="$EXTRA_BINDS --ro-bind $HOME/.local $HOME/.local"
[ -d "$HOME/.npm" ] && EXTRA_BINDS="$EXTRA_BINDS --bind $HOME/.npm $HOME/.npm"
[ -d "$HOME/.codex" ] && EXTRA_BINDS="$EXTRA_BINDS --bind $HOME/.codex $HOME/.codex"
[ -d "$HOME/.agents" ] && EXTRA_BINDS="$EXTRA_BINDS --bind $HOME/.agents $HOME/.agents"

bwrap \
  --ro-bind /usr /usr \
  --ro-bind /lib /lib \
  --ro-bind /lib64 /lib64 \
  --ro-bind /bin /bin \
  --ro-bind /etc/resolv.conf /etc/resolv.conf \
  --ro-bind /etc/hosts /etc/hosts \
  --ro-bind /etc/ssl /etc/ssl \
  --ro-bind /etc/ca-certificates /etc/ca-certificates \
  --ro-bind /etc/pkcs11 /etc/pkcs11 \
  --ro-bind /etc/passwd /etc/passwd \
  --ro-bind /etc/group /etc/group \
  $EXTRA_BINDS \
  $OPTIONAL_BINDS \
  --bind "$PWD" "$PWD" \
  --proc /proc \
  --dev /dev \
  --tmpfs /tmp \
  --setenv HOME "$HOME" \
  --setenv USER "$USER" \
  --share-net \
  --unshare-pid \
  --die-with-parent \
  --chdir "$PWD" \
  "$(which codex)" "$@"
