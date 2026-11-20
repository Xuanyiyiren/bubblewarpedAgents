#!/usr/bin/env bash

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
  --bind /tmp /tmp \
  --unsetenv DBUS_SESSION_BUS_ADDRESS \
  --unsetenv DBUS_SYSTEM_BUS_ADDRESS \
  --unsetenv SSH_AUTH_SOCK \
  --share-net \
  --unshare-pid \
  --die-with-parent \
  --chdir "$PWD" \
  claude --dangerously-skip-permissions --settings '{"sandbox":{"enabled":false}}' "$@"
