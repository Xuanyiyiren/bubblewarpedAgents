#!/usr/bin/env bash
# bwrapPiPaseo.sh: bwrapPiReadAll.sh for Paseo-launched pi.
# Only difference from bwrapPiReadAll.sh: files passed via --extension / --mcp-config
# (Paseo writes them under the host /tmp) are bound read-only into the sandbox,
# so the --tmpfs /tmp below does not hide them.

SCRIPT_PATH="$(realpath "$0")"

BASE_BINDS="
  --ro-bind / /
  --tmpfs /mnt
"

# These overrides must come after the broader filesystem bind they override.
OVERRIDE_BINDS="
  --ro-bind /dev/null /usr/bin/sudo
  --tmpfs /run/user/$(id -u)
  --tmpfs /run/dbus
"

# The $HOME directory is masked, and only the following paths are bound back in.
HOME_BINDS=""
[ -d "$HOME/.local" ] && HOME_BINDS="$HOME_BINDS --ro-bind $HOME/.local $HOME/.local"
[ -d "$HOME/.npm" ] && HOME_BINDS="$HOME_BINDS --ro-bind $HOME/.npm $HOME/.npm"
[ -d "$HOME/humanizer" ] && HOME_BINDS="$HOME_BINDS --ro-bind $HOME/humanizer $HOME/humanizer"
[ -d "$HOME/.agents" ] && HOME_BINDS="$HOME_BINDS --ro-bind $HOME/.agents $HOME/.agents"
[ -d "$HOME/.pi" ] && HOME_BINDS="$HOME_BINDS --bind $HOME/.pi $HOME/.pi"
[ -e "$PWD/.git" ] && PWD_GIT_BIND="--ro-bind $PWD/.git $PWD/.git"

# Files passed by Paseo, e.g. /tmp/paseo-pi-extension-*/paseo-integration.mjs.
# Bind the files themselves (not their directories) and only read-only.
PASEO_BINDS=()
args=("$@")
for ((i = 0; i < ${#args[@]}; i++)); do
  case "${args[i]}" in
    --extension|--mcp-config)
      f="${args[i+1]}"
      [ -f "$f" ] && PASEO_BINDS+=(--ro-bind "$f" "$f")
      ;;
  esac
done

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
  "${PASEO_BINDS[@]}" \
  --unsetenv DBUS_SESSION_BUS_ADDRESS \
  --unsetenv DBUS_SYSTEM_BUS_ADDRESS \
  --unsetenv SSH_AUTH_SOCK \
  --share-net \
  --unshare-pid \
  --die-with-parent \
  --chdir "$PWD" \
  pi --perm yolo "$@"
