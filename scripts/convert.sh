#!/bin/sh
# Turn an existing Debian @DEBIAN_BASE@ install into @OS_NAME@.
#
#   curl -fsSL @REPO_URL@/convert.sh | sudo sh -s -- desktop
#   curl -fsSL @REPO_URL@/convert.sh | sudo sh -s -- server
#   curl -fsSL @REPO_URL@/convert.sh | sudo sh -s -- gaming
#
# Safe to re-run. Remove with: apt purge 'cigamingos-*'
set -eu

EDITION="${1:-base}"
REPO="@REPO_URL@"
SUITE="@OS_CODENAME@"
KEYRING=/usr/share/keyrings/cigamingos-bootstrap.gpg   # replaced by cigamingos-keyring

say() { printf '\033[38;2;245;165;36m🦁 %s\033[0m\n' "$*"; }
die() { printf '✗ %s\n' "$*" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || die "run as root (sudo)"
. /etc/os-release
case "${DEBIAN_CODENAME:-${VERSION_CODENAME:-}}" in
  @DEBIAN_BASE@) ;;
  *) die "@OS_NAME@ needs Debian @DEBIAN_BASE@ (this is ${PRETTY_NAME:-unknown})" ;;
esac

case "$EDITION" in
  base)    PKGS="cigamingos-branding cigamingos-tools" ;;
  desktop) PKGS="cigamingos-desktop" ;;
  gaming)  PKGS="cigamingos-gaming" ;;
  server)  PKGS="cigamingos-server" ;;
  *) die "edition must be one of: base desktop gaming server" ;;
esac

say "Adding the @OS_NAME@ repository…"
apt-get update -qq
apt-get install -y -qq ca-certificates curl >/dev/null
curl -fsSL "$REPO/cigamingos-archive-keyring.gpg" -o "$KEYRING"
BOOT_SRC=/etc/apt/sources.list.d/cigamingos-bootstrap.sources
cat > "$BOOT_SRC" <<EOF
Types: deb
URIs: $REPO
Suites: $SUITE
Components: main
Signed-By: $KEYRING
EOF

# The desktop/gaming editions need contrib + non-free (Steam, firmware).
if [ "$EDITION" = desktop ] || [ "$EDITION" = gaming ]; then
  if [ -f /etc/apt/sources.list.d/debian.sources ]; then
    sed -i 's/^Components:.*/Components: main contrib non-free non-free-firmware/' /etc/apt/sources.list.d/debian.sources
  elif [ -f /etc/apt/sources.list ]; then
    sed -i -E '/^deb /{/contrib/!s/ main/ main contrib non-free non-free-firmware/}' /etc/apt/sources.list
  fi
fi
if [ "$EDITION" = gaming ]; then
  dpkg --add-architecture i386
  echo "steam steam/question select I AGREE" | debconf-set-selections
  echo "steam steam/license note ''" | debconf-set-selections
fi

apt-get update
say "Installing $PKGS (+ keyring)…"
# shellcheck disable=SC2086
DEBIAN_FRONTEND=noninteractive apt-get install -y cigamingos-keyring $PKGS

# cigamingos-keyring now owns the real apt source + key; drop the bootstrap copies.
rm -f "$BOOT_SRC" "$KEYRING"

# Desktop editions: make SDDM (the CiGaming login screen) the display manager,
# even when the machine already had GNOME's GDM. GNOME stays installed and
# selectable from the session menu.
if [ "$EDITION" = desktop ] || [ "$EDITION" = gaming ]; then
  if [ -x /usr/bin/sddm ]; then
    say "Switching the login screen to the CiGaming OS one (SDDM)…"
    echo "sddm shared/default-x-display-manager select sddm" | debconf-set-selections
    echo /usr/bin/sddm > /etc/X11/default-display-manager
    systemctl enable --force sddm.service >/dev/null 2>&1 || \
      ln -sfn /usr/lib/systemd/system/sddm.service /etc/systemd/system/display-manager.service
  fi
fi

say "Welcome to @OS_NAME@! Reboot to see the new boot splash. Try: cigaming fetch"
