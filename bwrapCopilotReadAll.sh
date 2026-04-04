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
[ -d "$HOME/.copilot" ] && HOME_BINDS="$HOME_BINDS --bind $HOME/.copilot $HOME/.copilot"
[ -d "$HOME/.cache/copilot" ] && HOME_BINDS="$HOME_BINDS --bind $HOME/.cache/copilot $HOME/.cache/copilot"
[ -d "$HOME/superpowers/skills" ] && HOME_BINDS="$HOME_BINDS --ro-bind $HOME/superpowers/skills $HOME/superpowers/skills"

bwrap \
  $BASE_BINDS \
  $OVERRIDE_BINDS \
  --tmpfs "$HOME" \
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
  "$HOME/.npm-global/bin/copilot" --allow-all "$@"
