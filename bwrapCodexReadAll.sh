#!/usr/bin/env bash

# Optional paths - only bind if they exist
OPTIONAL_BINDS=""
# [ -d "$HOME/.nvm" ] && OPTIONAL_BINDS="$OPTIONAL_BINDS --bind $HOME/.nvm $HOME/.nvm"
# [ -d "$HOME/.config/git" ] && OPTIONAL_BINDS="$OPTIONAL_BINDS --bind $HOME/.config/git $HOME/.config/git"
# [ -d "$HOME/.config/gh" ] && OPTIONAL_BINDS="$OPTIONAL_BINDS --bind $HOME/.config/gh $HOME/.config/gh"

# These paths might not exist
EXTRA_BINDS=""
[ -d "$HOME/.npm" ] && EXTRA_BINDS="$EXTRA_BINDS --bind $HOME/.npm $HOME/.npm"
[ -d "$HOME/.codex" ] && EXTRA_BINDS="$EXTRA_BINDS --bind $HOME/.codex $HOME/.codex"
[ -d "$HOME/.agents" ] && EXTRA_BINDS="$EXTRA_BINDS --bind $HOME/.agents $HOME/.agents"

bwrap \
  --ro-bind / / \
  $EXTRA_BINDS \
  $OPTIONAL_BINDS \
  --bind "$PWD" "$PWD" \
  --proc /proc \
  --dev /dev \
  --tmpfs /tmp \
  --share-net \
  --unshare-pid \
  --die-with-parent \
  --chdir "$PWD" \
  "$(which codex)" "$@"
