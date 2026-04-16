#!/usr/bin/env bash

SCRIPT_PATH="$(realpath "$0")"

BASE_BINDS="
  --ro-bind / /
"

# These overrides must come after the broader filesystem bind they override.
OVERRIDE_BINDS="
  --ro-bind /dev/null /usr/bin/sudo
"

# The $HOME directory is masked, and only the following paths are bound back in.
HOME_BINDS=""
[ -d "$HOME/.local" ] && HOME_BINDS="$HOME_BINDS --ro-bind $HOME/.local $HOME/.local"
[ -d "$HOME/.npm" ] && HOME_BINDS="$HOME_BINDS --ro-bind $HOME/.npm $HOME/.npm"
[ -d "$HOME/.npm-global" ] && HOME_BINDS="$HOME_BINDS --ro-bind $HOME/.npm-global $HOME/.npm-global"
# [ -d "$HOME/.agents" ] && HOME_BINDS="$HOME_BINDS --ro-bind $HOME/.agents $HOME/.agents"
[ -d "$HOME/.codex" ] && HOME_BINDS="$HOME_BINDS --bind $HOME/.codex $HOME/.codex"
[ -d "$HOME/superpowers/skills" ] && HOME_BINDS="$HOME_BINDS --ro-bind $HOME/superpowers/skills $HOME/superpowers/skills"
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
  codex --dangerously-bypass-approvals-and-sandbox "$@"
