#!/usr/bin/env bash

SCRIPT_PATH="$(realpath "$0")"
OPENCODE_CONFIG_FILE="$(mktemp /tmp/opencode-yolo.XXXXXX.jsonc)"
trap 'rm -f "$OPENCODE_CONFIG_FILE"' EXIT

cat > "$OPENCODE_CONFIG_FILE" <<'EOF'
{
  "$schema": "https://opencode.ai/config.json",
  "permission": "allow"
}
EOF

SYSTEM_BINDS="
  --ro-bind /usr /usr
  --ro-bind /lib /lib
  --ro-bind /lib64 /lib64
  --ro-bind /bin /bin
  --ro-bind /etc/resolv.conf /etc/resolv.conf
  --ro-bind /etc/hosts /etc/hosts
  --ro-bind /etc/ssl /etc/ssl
  --ro-bind /etc/ca-certificates /etc/ca-certificates
  --ro-bind /etc/pkcs11 /etc/pkcs11
  --ro-bind /etc/passwd /etc/passwd
  --ro-bind /etc/group /etc/group
"

[ -e "/etc/proxychains.conf" ] && SYSTEM_BINDS="$SYSTEM_BINDS --ro-bind /etc/proxychains.conf /etc/proxychains.conf"

# These overrides must come after the broader system binds they mask.
OVERRIDE_BINDS="
  --ro-bind /dev/null /usr/bin/sudo
"

# These paths might not exist.
HOME_BINDS=""
[ -d "$HOME/.local" ] && HOME_BINDS="$HOME_BINDS --ro-bind $HOME/.local $HOME/.local"
[ -d "$HOME/.npm" ] && HOME_BINDS="$HOME_BINDS --ro-bind $HOME/.npm $HOME/.npm"
[ -d "$HOME/.config/opencode" ] && HOME_BINDS="$HOME_BINDS --bind $HOME/.config/opencode $HOME/.config/opencode"
[ -d "$HOME/.local/share/opencode" ] && HOME_BINDS="$HOME_BINDS --bind $HOME/.local/share/opencode $HOME/.local/share/opencode"
[ -d "$HOME/.local/state/opencode" ] && HOME_BINDS="$HOME_BINDS --bind $HOME/.local/state/opencode $HOME/.local/state/opencode"
[ -d "$HOME/.cache/opencode" ] && HOME_BINDS="$HOME_BINDS --bind $HOME/.cache/opencode $HOME/.cache/opencode"
[ -e "$PWD/.git" ] && PWD_GIT_BIND="--ro-bind $PWD/.git $PWD/.git"

bwrap \
  $SYSTEM_BINDS \
  $OVERRIDE_BINDS \
  $HOME_BINDS \
  --bind "$PWD" "$PWD" \
  $PWD_GIT_BIND \
  --ro-bind "$SCRIPT_PATH" "$SCRIPT_PATH" \
  --proc /proc \
  --dev /dev \
  --tmpfs /tmp \
  --ro-bind "$OPENCODE_CONFIG_FILE" "$OPENCODE_CONFIG_FILE" \
  --share-net \
  --unshare-pid \
  --die-with-parent \
  --setenv OPENCODE_CONFIG "$OPENCODE_CONFIG_FILE" \
  --chdir "$PWD" \
  opencode "$@"
