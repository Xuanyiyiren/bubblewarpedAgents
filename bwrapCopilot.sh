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

[ -d "/etc/proxychains.conf" ] && SYSTEM_BINDS="$SYSTEM_BINDS --ro-bind /etc/proxychains.conf /etc/proxychains.conf"

# These overrides must come after the broader system binds they mask.
OVERRIDE_BINDS="
  --ro-bind /dev/null /usr/bin/sudo
"

# These paths might not exist.
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
[ -d "$HOME/.copilot" ] && HOME_BINDS="$HOME_BINDS --bind $HOME/.copilot $HOME/.copilot"
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
  --bind /tmp /tmp \
  --unsetenv DBUS_SESSION_BUS_ADDRESS \
  --unsetenv DBUS_SYSTEM_BUS_ADDRESS \
  --unsetenv SSH_AUTH_SOCK \
  --share-net \
  --unshare-pid \
  --die-with-parent \
  --chdir "$PWD" \
  "$HOME/.npm-global/bin/copilot" --allow-all "$@"
