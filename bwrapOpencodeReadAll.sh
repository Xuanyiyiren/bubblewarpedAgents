#!/usr/bin/env bash

SCRIPT_PATH="$(realpath "$0")"

# Runtime-only OpenCode override. This merges into the normal OpenCode config
# and keeps unrelated existing settings intact.
OPENCODE_CONFIG_CONTENT='{
  "permission": "allow",
  "agent": {
    "build": { "permission": { "*": "allow" } },
    "plan": { "permission": { "*": "allow" } },
    "general": { "permission": { "*": "allow" } },
    "explore": { "permission": { "*": "allow" } },
    "scout": { "permission": { "*": "allow" } },
    "compaction": { "permission": { "*": "allow" } },
    "title": { "permission": { "*": "allow" } },
    "summary": { "permission": { "*": "allow" } }
  }
}'

REPO_ROOT="$(git -C "$PWD" rev-parse --show-toplevel 2>/dev/null || true)"

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
[ -d "$HOME/.cache" ] && HOME_BINDS="$HOME_BINDS --bind $HOME/.cache $HOME/.cache"
[ -d "$HOME/.local" ] && HOME_BINDS="$HOME_BINDS --ro-bind $HOME/.local $HOME/.local"
[ -d "$HOME/.npm" ] && HOME_BINDS="$HOME_BINDS --ro-bind $HOME/.npm $HOME/.npm"
[ -d "$HOME/.agents" ] && HOME_BINDS="$HOME_BINDS --ro-bind $HOME/.agents $HOME/.agents"
[ -d "$HOME/micromamba" ] && HOME_BINDS="$HOME_BINDS --ro-bind $HOME/micromamba $HOME/micromamba"
[ -d "$HOME/vcpkg" ] && HOME_BINDS="$HOME_BINDS --ro-bind $HOME/vcpkg $HOME/vcpkg"
[ -d "$HOME/vcpkg/downloads" ] && HOME_BINDS="$HOME_BINDS --bind $HOME/vcpkg/downloads $HOME/vcpkg/downloads"
[ -d "$HOME/vcpkg/buildtrees" ] && HOME_BINDS="$HOME_BINDS --bind $HOME/vcpkg/buildtrees $HOME/vcpkg/buildtrees"
[ -d "$HOME/vcpkg/packages" ] && HOME_BINDS="$HOME_BINDS --bind $HOME/vcpkg/packages $HOME/vcpkg/packages"
[ -d "$HOME/vcpkg/installed" ] && HOME_BINDS="$HOME_BINDS --bind $HOME/vcpkg/installed $HOME/vcpkg/installed"
[ -d "$HOME/.config/opencode" ] && HOME_BINDS="$HOME_BINDS --bind $HOME/.config/opencode $HOME/.config/opencode"
[ -d "$HOME/.local/share/opencode" ] && HOME_BINDS="$HOME_BINDS --bind $HOME/.local/share/opencode $HOME/.local/share/opencode"
[ -d "$HOME/.local/state/opencode" ] && HOME_BINDS="$HOME_BINDS --bind $HOME/.local/state/opencode $HOME/.local/state/opencode"
[ -n "$REPO_ROOT" ] && HOME_BINDS="$HOME_BINDS --ro-bind $REPO_ROOT $REPO_ROOT"
[ -e "$PWD/.git" ] && PWD_GIT_BIND="--ro-bind $PWD/.git $PWD/.git"

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
  --bind /tmp /tmp \
  --unsetenv DBUS_SESSION_BUS_ADDRESS \
  --unsetenv DBUS_SYSTEM_BUS_ADDRESS \
  --unsetenv SSH_AUTH_SOCK \
  --share-net \
  --unshare-pid \
  --die-with-parent \
  --setenv OPENCODE_CONFIG_CONTENT "$OPENCODE_CONFIG_CONTENT" \
  --chdir "$PWD" \
  opencode "$@"
