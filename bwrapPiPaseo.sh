#!/usr/bin/env bash
# bwrapPiPaseo.sh: bwrapPiReadAll.sh for Paseo-launched pi.
# Files passed via --extension / --mcp-config are bound read-only after /tmp tmpfs.
# Paseo state (including worktrees) and worktrees' main repos are shared read-only.

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
[ -d "$HOME/micromamba" ] && HOME_BINDS="$HOME_BINDS --ro-bind $HOME/micromamba $HOME/micromamba"
[ -e "$PWD/.git" ] && PWD_GIT_BIND="--ro-bind $PWD/.git $PWD/.git"

# Paseo integration: prepare mounts here; bwrap applies them at the required positions below.
# Share Paseo config, state, and all projects' worktrees read-only.
[ -d "$HOME/.paseo" ] && HOME_BINDS="$HOME_BINDS --ro-bind $HOME/.paseo $HOME/.paseo"

# Worktree gitfiles point into the main repo, which is shared read-only.
if [ -f "$PWD/.git" ]; then
  GIT_COMMON_DIR="$(git -C "$PWD" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)"
  if [ -d "$GIT_COMMON_DIR" ]; then
    if [ "$(basename "$GIT_COMMON_DIR")" = ".git" ]; then
      MAIN_REPO="$(dirname "$GIT_COMMON_DIR")"
      HOME_BINDS="$HOME_BINDS --ro-bind $MAIN_REPO $MAIN_REPO"
    else
      # A separate Git directory's parent is not necessarily the main repo.
      PWD_GIT_BIND="$PWD_GIT_BIND --ro-bind $GIT_COMMON_DIR $GIT_COMMON_DIR"
    fi
  fi
fi

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

GPU_BINDS=()
for dev in /dev/nvidia[0-9]* /dev/nvidiactl /dev/nvidia-uvm \
           /dev/nvidia-uvm-tools /dev/nvidia-caps; do
  [ -e "$dev" ] && GPU_BINDS+=(--dev-bind-try "$dev" "$dev")
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
  "${GPU_BINDS[@]}" \
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
