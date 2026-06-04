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
"

# These overrides must come after the broader filesystem bind they override.
OVERRIDE_BINDS="
  --ro-bind /dev/null /usr/bin/sudo
"

# The $HOME directory is masked, and only the following paths are bound back in.
HOME_BINDS=""
[ -d "$HOME/.local" ] && HOME_BINDS="$HOME_BINDS --ro-bind $HOME/.local $HOME/.local"
[ -d "$HOME/.npm" ] && HOME_BINDS="$HOME_BINDS --ro-bind $HOME/.npm $HOME/.npm"
[ -d "$HOME/.config/opencode" ] && HOME_BINDS="$HOME_BINDS --bind $HOME/.config/opencode $HOME/.config/opencode"
[ -d "$HOME/.local/share/opencode" ] && HOME_BINDS="$HOME_BINDS --bind $HOME/.local/share/opencode $HOME/.local/share/opencode"
[ -d "$HOME/.local/state/opencode" ] && HOME_BINDS="$HOME_BINDS --bind $HOME/.local/state/opencode $HOME/.local/state/opencode"
[ -d "$HOME/.cache/opencode" ] && HOME_BINDS="$HOME_BINDS --bind $HOME/.cache/opencode $HOME/.cache/opencode"
[ -n "$REPO_ROOT" ] && HOME_BINDS="$HOME_BINDS --ro-bind $REPO_ROOT $REPO_ROOT"
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
  --setenv OPENCODE_CONFIG_CONTENT "$OPENCODE_CONFIG_CONTENT" \
  --chdir "$PWD" \
  opencode "$@"
