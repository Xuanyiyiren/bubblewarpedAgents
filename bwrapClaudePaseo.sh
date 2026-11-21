#!/usr/bin/env bash
# bwrapClaudePaseo.sh: bwrapClaudeReadAll.sh for Paseo-launched claude.
# Paseo passes MCP servers as inline JSON, so no config files need binding.
# Sessions always start in bypass mode: Paseo's --permission-mode is dropped, since the
# enclosing bwrap is the boundary. Switching modes in Paseo mid-session still works.
# Claude's own sandbox is disabled for the same reason.
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
[ -d "$HOME/.cache" ] && HOME_BINDS="$HOME_BINDS --bind $HOME/.cache $HOME/.cache"
[ -d "$HOME/.local" ] && HOME_BINDS="$HOME_BINDS --ro-bind $HOME/.local $HOME/.local"
[ -d "$HOME/.npm" ] && HOME_BINDS="$HOME_BINDS --ro-bind $HOME/.npm $HOME/.npm"
[ -d "$HOME/humanizer" ] && HOME_BINDS="$HOME_BINDS --ro-bind $HOME/humanizer $HOME/humanizer"
[ -d "$HOME/.agents" ] && HOME_BINDS="$HOME_BINDS --ro-bind $HOME/.agents $HOME/.agents"
[ -d "$HOME/micromamba" ] && HOME_BINDS="$HOME_BINDS --ro-bind $HOME/micromamba $HOME/micromamba"
[ -d "$HOME/vcpkg" ] && HOME_BINDS="$HOME_BINDS --ro-bind $HOME/vcpkg $HOME/vcpkg"
[ -d "$HOME/vcpkg/downloads" ] && HOME_BINDS="$HOME_BINDS --bind $HOME/vcpkg/downloads $HOME/vcpkg/downloads"
[ -d "$HOME/vcpkg/buildtrees" ] && HOME_BINDS="$HOME_BINDS --bind $HOME/vcpkg/buildtrees $HOME/vcpkg/buildtrees"
[ -d "$HOME/vcpkg/packages" ] && HOME_BINDS="$HOME_BINDS --bind $HOME/vcpkg/packages $HOME/vcpkg/packages"
[ -d "$HOME/vcpkg/installed" ] && HOME_BINDS="$HOME_BINDS --bind $HOME/vcpkg/installed $HOME/vcpkg/installed"
[ -d "$HOME/.claude" ] && HOME_BINDS="$HOME_BINDS --bind $HOME/.claude $HOME/.claude"
[ -f "$HOME/.claude.json" ] && HOME_BINDS="$HOME_BINDS --bind $HOME/.claude.json $HOME/.claude.json"
# Like .git: config that an unwrapped claude on the host would load and execute stays read-only.
# Missing paths are skipped, so create them on the host first:
#   mkdir -p ~/.claude/{hooks,commands,agents} && touch ~/.claude/CLAUDE.md
[ -e "$HOME/.claude/settings.json" ] && HOME_BINDS="$HOME_BINDS --ro-bind $HOME/.claude/settings.json $HOME/.claude/settings.json"
[ -e "$HOME/.claude/CLAUDE.md" ] && HOME_BINDS="$HOME_BINDS --ro-bind $HOME/.claude/CLAUDE.md $HOME/.claude/CLAUDE.md"
[ -e "$HOME/.claude/hooks" ] && HOME_BINDS="$HOME_BINDS --ro-bind $HOME/.claude/hooks $HOME/.claude/hooks"
[ -e "$HOME/.claude/plugins" ] && HOME_BINDS="$HOME_BINDS --ro-bind $HOME/.claude/plugins $HOME/.claude/plugins"
[ -e "$HOME/.claude/commands" ] && HOME_BINDS="$HOME_BINDS --ro-bind $HOME/.claude/commands $HOME/.claude/commands"
[ -e "$HOME/.claude/agents" ] && HOME_BINDS="$HOME_BINDS --ro-bind $HOME/.claude/agents $HOME/.claude/agents"
[ -e "$HOME/.claude/skills" ] && HOME_BINDS="$HOME_BINDS --ro-bind $HOME/.claude/skills $HOME/.claude/skills"
[ -e "$PWD/.git" ] && PWD_GIT_BIND="--ro-bind $PWD/.git $PWD/.git"
[ -e "$PWD/.claude" ] && PWD_CLAUDE_BINDS="--ro-bind $PWD/.claude $PWD/.claude"
[ -e "$PWD/.mcp.json" ] && PWD_CLAUDE_BINDS="$PWD_CLAUDE_BINDS --ro-bind $PWD/.mcp.json $PWD/.mcp.json"

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

# Drop Paseo's --permission-mode so --dangerously-skip-permissions below takes effect.
# Paseo (via the SDK) also passes its own --settings, and claude keeps only the last one,
# so take Paseo's out here and merge it with ours below.
SANDBOX_OFF='{"sandbox":{"enabled":false}}'
PASEO_SETTINGS='{}'
CLAUDE_ARGS=()
skip_next=0
take_settings=0
for a in "$@"; do
  if [ "$skip_next" = 1 ]; then skip_next=0; continue; fi
  if [ "$take_settings" = 1 ]; then take_settings=0; PASEO_SETTINGS="$a"; continue; fi
  case "$a" in
    --permission-mode) skip_next=1 ;;
    --permission-mode=*) ;;
    --settings) take_settings=1 ;;
    --settings=*) PASEO_SETTINGS="${a#--settings=}" ;;
    *) CLAUDE_ARGS+=("$a") ;;
  esac
done

# --settings also accepts a file path. Our sandbox override wins; fail rather than drop settings.
[ -f "$PASEO_SETTINGS" ] && PASEO_SETTINGS="$(cat "$PASEO_SETTINGS")"
SETTINGS="$(jq -cn --argjson p "$PASEO_SETTINGS" --argjson o "$SANDBOX_OFF" '$p * $o')" \
  || { echo "bwrapClaudePaseo.sh: cannot merge Paseo's --settings" >&2; exit 1; }

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
  $PWD_CLAUDE_BINDS \
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
  --chdir "$PWD" \
  claude --dangerously-skip-permissions --settings "$SETTINGS" "${CLAUDE_ARGS[@]}"
