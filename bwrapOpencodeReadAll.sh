#!/usr/bin/env bash

SCRIPT_PATH="$(realpath "$0")"
OPENCODE_CONFIG_FILE="$(mktemp /tmp/opencode-yolo.XXXXXX.jsonc)"
trap 'rm -f "$OPENCODE_CONFIG_FILE"' EXIT

USER_OPENCODE_CONFIG="$HOME/.config/opencode/opencode.jsonc"

jsonc_to_json() {
  perl -0pe 's/^\x{FEFF}//; s{"(?:\\.|[^"\\])*"(*SKIP)(*F)|//.*?$|/\*.*?\*/}{}gms; s!"(?:\\.|[^"\\])*"(*SKIP)(*F)|,\s*([}\]])!$1!gms'
}

if ! jsonc_to_json < "$USER_OPENCODE_CONFIG" | jq 'if type == "object" then .permission = "allow" else error("OpenCode config must be a JSON object") end' > "$OPENCODE_CONFIG_FILE"; then
  printf 'Failed to merge OpenCode config from %s\n' "$USER_OPENCODE_CONFIG" >&2
  exit 1
fi

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
  # after --tmpfs /tmp
  --ro-bind "$OPENCODE_CONFIG_FILE" "$OPENCODE_CONFIG_FILE" \
  --share-net \
  --unshare-pid \
  --die-with-parent \
  --setenv OPENCODE_CONFIG "$OPENCODE_CONFIG_FILE" \
  --chdir "$PWD" \
  opencode "$@"
