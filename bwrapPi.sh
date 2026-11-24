#!/usr/bin/env bash

SCRIPT_PATH="$(realpath "$0")"

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
[ -d "$HOME/.cache" ] && HOME_BINDS="$HOME_BINDS --bind $HOME/.cache $HOME/.cache"
[ -d "$HOME/.local" ] && HOME_BINDS="$HOME_BINDS --ro-bind $HOME/.local $HOME/.local"
[ -d "$HOME/.npm" ] && HOME_BINDS="$HOME_BINDS --ro-bind $HOME/.npm $HOME/.npm"
[ -d "$HOME/.agents" ] && HOME_BINDS="$HOME_BINDS --ro-bind $HOME/.agents $HOME/.agents"
[ -d "$HOME/.pi" ] && HOME_BINDS="$HOME_BINDS --bind $HOME/.pi $HOME/.pi"
# Like .git: config that an unwrapped pi on the host would load and execute stays read-only.
# Missing paths are skipped.
[ -e "$HOME/.pi/agent/AGENTS.md" ] && HOME_BINDS="$HOME_BINDS --ro-bind $HOME/.pi/agent/AGENTS.md $HOME/.pi/agent/AGENTS.md"
[ -e "$HOME/.pi/agent/settings.json" ] && HOME_BINDS="$HOME_BINDS --ro-bind $HOME/.pi/agent/settings.json $HOME/.pi/agent/settings.json"
[ -e "$HOME/.pi/agent/models.json" ] && HOME_BINDS="$HOME_BINDS --ro-bind $HOME/.pi/agent/models.json $HOME/.pi/agent/models.json"
[ -e "$HOME/.pi/agent/trust.json" ] && HOME_BINDS="$HOME_BINDS --ro-bind $HOME/.pi/agent/trust.json $HOME/.pi/agent/trust.json"
[ -e "$HOME/.pi/agent/npm" ] && HOME_BINDS="$HOME_BINDS --ro-bind $HOME/.pi/agent/npm $HOME/.pi/agent/npm"
[ -e "$HOME/.pi/agent/git" ] && HOME_BINDS="$HOME_BINDS --ro-bind $HOME/.pi/agent/git $HOME/.pi/agent/git"
[ -e "$HOME/.pi/agent/extensions" ] && HOME_BINDS="$HOME_BINDS --ro-bind $HOME/.pi/agent/extensions $HOME/.pi/agent/extensions"
[ -e "$HOME/.pi/agent/skills" ] && HOME_BINDS="$HOME_BINDS --ro-bind $HOME/.pi/agent/skills $HOME/.pi/agent/skills"
[ -e "$HOME/.pi/agent/prompts" ] && HOME_BINDS="$HOME_BINDS --ro-bind $HOME/.pi/agent/prompts $HOME/.pi/agent/prompts"
[ -d "$HOME/micromamba" ] && HOME_BINDS="$HOME_BINDS --ro-bind $HOME/micromamba $HOME/micromamba"
[ -d "$HOME/vcpkg" ] && HOME_BINDS="$HOME_BINDS --ro-bind $HOME/vcpkg $HOME/vcpkg"
[ -d "$HOME/vcpkg/downloads" ] && HOME_BINDS="$HOME_BINDS --bind $HOME/vcpkg/downloads $HOME/vcpkg/downloads"
[ -d "$HOME/vcpkg/buildtrees" ] && HOME_BINDS="$HOME_BINDS --bind $HOME/vcpkg/buildtrees $HOME/vcpkg/buildtrees"
[ -d "$HOME/vcpkg/packages" ] && HOME_BINDS="$HOME_BINDS --bind $HOME/vcpkg/packages $HOME/vcpkg/packages"
[ -d "$HOME/vcpkg/installed" ] && HOME_BINDS="$HOME_BINDS --bind $HOME/vcpkg/installed $HOME/vcpkg/installed"
[ -e "$PWD/.git" ] && PWD_GIT_BIND="--ro-bind $PWD/.git $PWD/.git"

GPU_BINDS=()
for dev in /dev/nvidia[0-9]* /dev/nvidiactl /dev/nvidia-uvm \
           /dev/nvidia-uvm-tools /dev/nvidia-caps; do
  [ -e "$dev" ] && GPU_BINDS+=(--dev-bind-try "$dev" "$dev")
done

bwrap \
  $SYSTEM_BINDS \
  $OVERRIDE_BINDS \
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
  --chdir "$PWD" \
  pi --perm yolo "$@"
