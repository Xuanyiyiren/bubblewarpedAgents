#!/usr/bin/env bash

SCRIPT_PATH="$(realpath "$0")"

BASE_BINDS="
  --ro-bind / /
  --tmpfs /mnt
"

# These overrides must come after the broader filesystem bind they override.
OVERRIDE_BINDS="
  --ro-bind /dev/null /usr/bin/sudo
"

# The $HOME directory is masked, and only the following paths are bound back in.
HOME_BINDS=""
[ -d "$HOME/.local" ] && HOME_BINDS="$HOME_BINDS --ro-bind $HOME/.local $HOME/.local"
[ -d "$HOME/.npm" ] && HOME_BINDS="$HOME_BINDS --ro-bind $HOME/.npm $HOME/.npm"
[ -d "$HOME/humanizer" ] && HOME_BINDS="$HOME_BINDS --ro-bind $HOME/humanizer $HOME/humanizer"
[ -d "$HOME/.claude" ] && HOME_BINDS="$HOME_BINDS --bind $HOME/.claude $HOME/.claude"
[ -f "$HOME/.claude.json" ] && HOME_BINDS="$HOME_BINDS --bind $HOME/.claude.json $HOME/.claude.json"
[ -e "$PWD/.git" ] && PWD_GIT_BIND="--ro-bind $PWD/.git $PWD/.git"

bwrap \
  $BASE_BINDS \
  $OVERRIDE_BINDS \
  --tmpfs "$HOME" \
  $HOME_BINDS \
  --bind "$PWD" "$PWD" \
  $PWD_GIT_BIND \
  --ro-bind "$SCRIPT_PATH" "$SCRIPT_PATH" \
  --proc /proc \
  --dev /dev \
  --tmpfs /tmp \
  --share-net \
  --unshare-pid \
  --die-with-parent \
  --chdir "$PWD" \
  claude --dangerously-skip-permissions "$@"
