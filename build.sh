#!/usr/bin/env bash
# Build a bootable CiGaming OS ISO.
#
#   sudo ./build.sh desktop      # KDE: streaming + gaming + community (Calamares installer)
#   sudo ./build.sh server       # headless fleet server (text installer)
#
# Run on Debian trixie (or in a debian:trixie container with --privileged).
# Needs: live-build, librsvg2-bin, dpkg-dev — `make deps` installs them.
#
# Output: dist/cigamingos-<version>-<edition>-amd64.iso (+ .sha256)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
EDITION="${1:-}"
# shellcheck source=branding/palette.env
source "$ROOT/branding/palette.env"
VERSION="$(tr -d '[:space:]' < "$ROOT/VERSION")"
ARCH=amd64
WORK="$ROOT/build/iso-$EDITION"
DIST="$ROOT/dist"
MIRROR="${MIRROR:-http://deb.debian.org/debian/}"

case "$EDITION" in
  desktop|server) ;;
  *) echo "usage: sudo $0 desktop|server" >&2; exit 1 ;;
esac
[ "$(id -u)" -eq 0 ] || { echo "live-build needs root: sudo $0 $EDITION" >&2; exit 1; }
command -v lb >/dev/null || { echo "live-build missing — run: make deps" >&2; exit 1; }

step() { printf '\n\033[38;2;245;165;36m🦁 %s\033[0m\n' "$*"; }

# 1. our packages ------------------------------------------------------------
if [ "${SKIP_PACKAGES:-0}" != 1 ] || ! ls "$ROOT"/build/debs/*.deb >/dev/null 2>&1; then
  step "Building CiGaming OS packages"
  "$ROOT/scripts/build-packages.sh"
fi

# 2. fresh live-build tree ---------------------------------------------------
step "Configuring live-build for the $EDITION edition"
mkdir -p "$WORK" "$DIST"
cd "$WORK"
lb clean >/dev/null 2>&1 || true   # keeps cache/ so rebuilds skip re-downloading
rm -rf config

COMMON=(
  --mode debian
  --distribution "$DEBIAN_BASE"
  --architectures "$ARCH"
  --archive-areas "main contrib non-free non-free-firmware"
  --mirror-bootstrap "$MIRROR"
  --mirror-chroot "$MIRROR"
  --mirror-binary "http://deb.debian.org/debian/"
  --mirror-binary-security "http://security.debian.org/debian-security/"
  --security true
  --updates true
  --binary-images iso-hybrid
  --firmware-chroot false   # explicit list in editions/common/package-lists/firmware.list.chroot
  --firmware-binary true
  --memtest none
  --checksums sha256
  --iso-application "$OS_NAME"
  --iso-publisher "CiGaming; $HOME_URL"
  --iso-preparer "CiGaming OS build.sh (live-build)"
  --image-name "cigamingos-$VERSION-$EDITION"
  --cache true
)
VOL="CIGAMINGOS_${VERSION//./_}"; VOL="${VOL:0:24}"
if [ "$EDITION" = desktop ]; then
  lb config "${COMMON[@]}" \
    --iso-volume "${VOL}_DESKTOP" \
    --apt-recommends true \
    --debian-installer none \
    --bootappend-live "boot=live components quiet splash username=cub user-fullname=Cub hostname=cigamingos locales=en_US.UTF-8 keyboard-layouts=us"
else
  lb config "${COMMON[@]}" \
    --iso-volume "${VOL}_SERVER" \
    --apt-recommends false \
    --debian-installer live \
    --debian-installer-gui false \
    --bootappend-live "boot=live components quiet username=cub user-fullname=Cub hostname=cigamingos-server locales=en_US.UTF-8 keyboard-layouts=us"
fi

# 3. layer our config on top -------------------------------------------------
cp -a "$ROOT/editions/common/." config/
cp -a "$ROOT/editions/$EDITION/." config/
chmod +x config/hooks/live/*.hook.*

# live-build installs EVERY .deb in packages.chroot, so copy only the
# cigamingos-* packages this edition's package lists ask for.
mkdir -p config/packages.chroot
for pkg in $(grep -hoE '^cigamingos-[a-z-]+' config/package-lists/*.list.chroot | sort -u); do
  deb=$(ls "$ROOT"/build/debs/"${pkg}"_*.deb 2>/dev/null | head -1 || true)
  if [ -n "$deb" ]; then cp "$deb" config/packages.chroot/
  elif [ "$pkg" != cigamingos-keyring ]; then echo "missing $pkg .deb — run scripts/build-packages.sh" >&2; exit 1
  fi
done
echo "  local packages: $(cd config/packages.chroot && ls | tr '\n' ' ')"

# Only switch the image to our own apt repo once it's actually online,
# otherwise apt inside the build would fail on it.
if ! ls config/packages.chroot/cigamingos-keyring_*.deb >/dev/null 2>&1 || \
   ! curl -fsS --max-time 10 -o /dev/null "$REPO_URL/dists/$OS_CODENAME/InRelease"; then
  echo "  ! $REPO_URL isn't serving $OS_CODENAME yet — building without the CiGaming repo enabled"
  sed -i '/^cigamingos-keyring$/d' config/package-lists/*.list.chroot
  rm -f config/packages.chroot/cigamingos-keyring_*.deb
fi

# Brand the live USB boot menus (syslinux/isolinux + GRUB) with our splash.
for b in syslinux_common isolinux grub-pc; do
  src="/usr/share/live/build/bootloaders/$b"
  [ -d "$src" ] || continue
  mkdir -p config/bootloaders
  cp -a "$src" config/bootloaders/
  find "config/bootloaders/$b" -name 'splash.svg' -delete
  find "config/bootloaders/$b" -name 'splash.png' -exec cp "$ROOT/build/assets/isolinux-splash.png" {} \;
  [ -f "config/bootloaders/$b/splash.png" ] || cp "$ROOT/build/assets/isolinux-splash.png" "config/bootloaders/$b/splash.png"
  grep -rl "Debian GNU/Linux\|Live system" "config/bootloaders/$b" 2>/dev/null | \
    xargs -r sed -i -e "s/Debian GNU\/Linux/$OS_NAME/g" -e "s/Live system/$OS_NAME Live/g" || true
done

# 4. build -------------------------------------------------------------------
step "Building the ISO (this takes a while — grab a juice box)"
lb build 2>&1 | tee "$WORK/build.log"

ISO=$(ls -1t "$WORK"/*.iso 2>/dev/null | head -1 || true)
[ -n "$ISO" ] || { echo "No ISO produced — see $WORK/build.log" >&2; exit 1; }
OUT="$DIST/cigamingos-$VERSION-$EDITION-$ARCH.iso"
mv "$ISO" "$OUT"
(cd "$DIST" && sha256sum "$(basename "$OUT")" > "$(basename "$OUT").sha256")

step "Done: $OUT ($(du -h "$OUT" | cut -f1))"
echo "Test it:  qemu-system-x86_64 -m 4G -enable-kvm -cdrom $OUT"
echo "Flash it: sudo dd if=$OUT of=/dev/sdX bs=4M status=progress oflag=sync"
