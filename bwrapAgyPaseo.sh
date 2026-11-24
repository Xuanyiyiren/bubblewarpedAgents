#!/usr/bin/env bash
# bwrapAgyPaseo.sh: bwrapAgyReadAll.sh for Paseo-launched agy (via ACP).
# Paseo passes MCP servers over ACP JSON-RPC, so no /tmp config files need binding.
# Sessions start with --dangerously-skip-permissions since the enclosing bwrap is the boundary.
# Paseo state (including worktrees) and worktrees' main repos are shared read-only.
# A stdio JSON-RPC filter disables ACP host terminal/fs RPCs so the sandbox cannot delegate
# execution or file I/O back to the unsandboxed Paseo daemon.

# Paseo probes availability with "<launcher> --version"; no sandbox or ACP filter needed.
if [ "${1:-}" = "--version" ] || [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  exec agy "$@"
fi

SCRIPT_PATH="$(realpath "$0")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"
ACP_FILTER="$SCRIPT_DIR/acpFilter.py"

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
[ -d "$HOME/.gemini/antigravity-cli" ] && HOME_BINDS="$HOME_BINDS --bind $HOME/.gemini/antigravity-cli $HOME/.gemini/antigravity-cli"
# agy prepends bin/ to PATH for its agentapi shim; keep it ephemeral so the host PATH can't be hijacked.
[ -d "$HOME/.gemini/antigravity-cli" ] && HOME_BINDS="$HOME_BINDS --tmpfs $HOME/.gemini/antigravity-cli/bin"
# Like .git: config that an unwrapped agy on the host would load and execute stays read-only.
[ -e "$HOME/.gemini/antigravity-cli/settings.json" ] && HOME_BINDS="$HOME_BINDS --ro-bind $HOME/.gemini/antigravity-cli/settings.json $HOME/.gemini/antigravity-cli/settings.json"
[ -d "$HOME/.gemini/antigravity-cli/builtin" ] && HOME_BINDS="$HOME_BINDS --ro-bind $HOME/.gemini/antigravity-cli/builtin $HOME/.gemini/antigravity-cli/builtin"
# Keeping ~/.gemini/config read-only as a whole also prevents creating hooks.json or plugins/.
[ -d "$HOME/.gemini/config" ] && HOME_BINDS="$HOME_BINDS --ro-bind $HOME/.gemini/config $HOME/.gemini/config"
[ -e "$PWD/.git" ] && PWD_GIT_BIND="--ro-bind $PWD/.git $PWD/.git"
PWD_AGY_BINDS=""
[ -e "$PWD/.agents" ] && PWD_AGY_BINDS="$PWD_AGY_BINDS --ro-bind $PWD/.agents $PWD/.agents"
[ -e "$PWD/.agent" ] && PWD_AGY_BINDS="$PWD_AGY_BINDS --ro-bind $PWD/.agent $PWD/.agent"
[ -e "$PWD/_agents" ] && PWD_AGY_BINDS="$PWD_AGY_BINDS --ro-bind $PWD/_agents $PWD/_agents"
[ -e "$PWD/_agent" ] && PWD_AGY_BINDS="$PWD_AGY_BINDS --ro-bind $PWD/_agent $PWD/_agent"

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

GPU_BINDS=()
for dev in /dev/nvidia[0-9]* /dev/nvidiactl /dev/nvidia-uvm \
           /dev/nvidia-uvm-tools /dev/nvidia-caps; do
  [ -e "$dev" ] && GPU_BINDS+=(--dev-bind-try "$dev" "$dev")
done

# Accept either ".../bwrapAgyPaseo.sh" or ".../bwrapAgyPaseo.sh acp ..." in Paseo config.
[ "${1:-}" = "acp" ] && shift

# Filter ACP stdio JSON-RPC at the sandbox boundary via acpFilter.py.
if [ ! -f "$ACP_FILTER" ]; then
  echo "bwrapAgyPaseo.sh: missing ACP filter: $ACP_FILTER" >&2
  exit 1
fi

exec python3 -I -u "$ACP_FILTER" bwrap \
  $BASE_BINDS \
  $OVERRIDE_BINDS \
  --tmpfs "$HOME" \
  $HOME_BINDS \
  --bind "$PWD" "$PWD" \
  $PWD_GIT_BIND \
  $PWD_AGY_BINDS \
  --ro-bind "$SCRIPT_PATH" "$SCRIPT_PATH" \
  --ro-bind "$ACP_FILTER" "$ACP_FILTER" \
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
  --chdir "$PWD" \
  agy acp --dangerously-skip-permissions "$@"
