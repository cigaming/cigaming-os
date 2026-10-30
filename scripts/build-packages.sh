#!/usr/bin/env bash
# Build every CiGaming OS .deb from packages/<name>/ into build/debs/.
#
#   packages/<name>/DEBIAN/...   control(.in), maintainer scripts
#   packages/<name>/<fs tree>    files installed as-is
#   *.in files                   @TOKENS@ substituted, .in suffix dropped
#
# Needs: dpkg-deb, rsvg-convert, gzip
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT/build"
OUT="$BUILD/debs"
# shellcheck source=../branding/palette.env
source "$ROOT/branding/palette.env"
VERSION="$(tr -d '[:space:]' < "$ROOT/VERSION")"
REPO_HOST="${REPO_URL#*://}"; REPO_HOST="${REPO_HOST%%/*}"

[ -f "$BUILD/assets/logo-512.png" ] || "$ROOT/scripts/render-assets.sh"

hex_rgb()   { local h=${1#\#}; printf '%d,%d,%d' "0x${h:0:2}" "0x${h:2:2}" "0x${h:4:2}"; }
hex_float() { local h=${1#\#}; awk -v r=$((16#${h:0:2})) -v g=$((16#${h:2:2})) -v b=$((16#${h:4:2})) \
                'BEGIN{printf "%.3f, %.3f, %.3f", r/255, g/255, b/255}'; }

subst() { # subst <file>  — in-place token replacement
  sed -i \
    -e "s|@VERSION@|$VERSION|g" -e "s|@OS_NAME@|$OS_NAME|g" -e "s|@OS_ID@|$OS_ID|g" \
    -e "s|@OS_VERSION@|$OS_VERSION|g" -e "s|@OS_CODENAME@|$OS_CODENAME|g" \
    -e "s|@OS_CODENAME_PRETTY@|$OS_CODENAME_PRETTY|g" -e "s|@DEBIAN_BASE@|$DEBIAN_BASE|g" \
    -e "s|@HOME_URL@|$HOME_URL|g" -e "s|@SUPPORT_URL@|$SUPPORT_URL|g" -e "s|@BUG_URL@|$BUG_URL|g" \
    -e "s|@REPO_URL@|$REPO_URL|g" -e "s|@REPO_HOST@|$REPO_HOST|g" \
    -e "s|@NIGHT_KDE@|$(hex_rgb "$NIGHT")|g" -e "s|@PLUM_KDE@|$(hex_rgb "$PLUM")|g" \
    -e "s|@DUSK_KDE@|$(hex_rgb "$DUSK")|g" -e "s|@AMBER_KDE@|$(hex_rgb "$AMBER")|g" \
    -e "s|@MANE_KDE@|$(hex_rgb "$MANE")|g" -e "s|@CREAM_KDE@|$(hex_rgb "$CREAM")|g" \
    -e "s|@TEAL_KDE@|$(hex_rgb "$TEAL")|g" \
    -e "s|@NIGHT_RGB@|$(hex_float "$NIGHT")|g" -e "s|@PLUM_RGB@|$(hex_float "$PLUM")|g" \
    -e "s|@CREAM_F@|$(hex_float "$CREAM")|g" -e "s|@AMBER_F@|$(hex_float "$AMBER")|g" \
    -e "s|@NIGHT_HEX@|$NIGHT|g" -e "s|@CREAM_HEX@|$CREAM|g" -e "s|@AMBER_HEX@|$AMBER|g" \
    "$1"
}

add_branding_assets() { # add_branding_assets <pkgroot>
  local r=$1 a="$BUILD/assets" t="$1/usr/share/desktop-base/cigamingos-theme"
  # desktop-base theme (wallpaper, lockscreen, SDDM login, GRUB)
  for d in wallpaper lockscreen; do
    mkdir -p "$t/$d/contents/images"
    cp "$a/wallpaper-3840x2160.png" "$t/$d/contents/images/3840x2160.png"
    cp "$a/wallpaper-1920x1080.png" "$t/$d/contents/images/1920x1080.png"
    cp "$a/wallpaper-1280x1024.png" "$t/$d/contents/images/1280x1024.png" 2>/dev/null || true
    cp "$a/wallpaper.svg" "$t/$d/contents/images/3840x2160.svg"
  done
  cp "$t/wallpaper/metadata.json" "$t/lockscreen/metadata.json"
  cp "$t/wallpaper/gnome-background.xml" "$t/lockscreen/gnome-background.xml"
  mkdir -p "$t/login" "$t/grub"
  cp "$a/wallpaper.svg" "$t/login/background.svg"
  cp "$a/wallpaper-1920x1080.png" "$t/login/background.png"
  cp "$a/grub-16x9.png" "$t/grub/grub-16x9.png"
  cp "$a/grub-4x3.png"  "$t/grub/grub-4x3.png"
  # Plasma wallpaper picker entry
  mkdir -p "$r/usr/share/wallpapers"
  ln -sfn ../desktop-base/cigamingos-theme/wallpaper "$r/usr/share/wallpapers/CiGamingOS"
  # icons
  for s in 16 22 24 32 48 64 128 256 512; do
    mkdir -p "$r/usr/share/icons/hicolor/${s}x${s}/apps"
    cp "$a/logo-$s.png" "$r/usr/share/icons/hicolor/${s}x${s}/apps/cigamingos.png"
  done
  mkdir -p "$r/usr/share/icons/hicolor/scalable/apps" "$r/usr/share/pixmaps"
  cp "$a/logo.svg" "$r/usr/share/icons/hicolor/scalable/apps/cigamingos.svg"
  cp "$a/logo-256.png" "$r/usr/share/pixmaps/cigamingos.png"
  # Plymouth
  local p="$r/usr/share/plymouth/themes/cigamingos"
  cp "$a/logo-256.png" "$p/logo.png"
  rsvg-convert -w 8 -h 8 <(printf '<svg xmlns="http://www.w3.org/2000/svg" width="8" height="8"><rect width="8" height="8" fill="%s"/></svg>' "$DUSK") -o "$p/bar-track.png"
  rsvg-convert -w 8 -h 8 <(printf '<svg xmlns="http://www.w3.org/2000/svg" width="8" height="8"><rect width="8" height="8" fill="%s"/></svg>' "$AMBER") -o "$p/bar-fill.png"
}

add_keyring() { # add_keyring <pkgroot> — returns 1 if no key yet
  local key="$ROOT/keys/cigamingos-archive.asc"
  if [ ! -f "$key" ]; then
    echo "  ! keys/cigamingos-archive.asc not found — skipping cigamingos-keyring (run scripts/repo-keygen.sh)" >&2
    return 1
  fi
  mkdir -p "$1/usr/share/keyrings"
  gpg --dearmor < "$key" > "$1/usr/share/keyrings/cigamingos-archive-keyring.gpg"
}

rm -rf "$BUILD/pkgroot" "$OUT"; mkdir -p "$BUILD/pkgroot" "$OUT"

for src in "$ROOT"/packages/*/; do
  name=$(basename "$src")
  r="$BUILD/pkgroot/$name"
  echo "• $name $VERSION"
  cp -a "$src" "$r"

  case "$name" in
    cigamingos-keyring) add_keyring "$r" || { rm -rf "$r"; continue; } ;;
  esac

  # template pass
  while IFS= read -r -d '' f; do subst "$f"; mv "$f" "${f%.in}"; done \
    < <(find "$r" -type f -name '*.in' -print0)

  case "$name" in
    cigamingos-branding) add_branding_assets "$r" ;;
    cigamingos-installer)
      b="$r/etc/calamares/branding/cigamingos"
      cp "$BUILD/assets/logo-256.png" "$b/logo.png"
      cp "$BUILD/assets/calamares-welcome.png" "$b/welcome.png" ;;
    cigamingos-tools)    mkdir -p "$r/usr/share/cigamingos"; echo "$OS_NAME $VERSION" > "$r/usr/share/cigamingos/version" ;;
  esac

  # docs every package should carry
  d="$r/usr/share/doc/$name"; mkdir -p "$d"
  cat > "$d/copyright" <<EOF
Format: https://www.debian.org/doc/packaging-manuals/copyright-format/1.0/
Upstream-Name: $name
Source: $HOME_URL

Files: *
Copyright: $(date +%Y) CiGaming / Cloud Data Hosting LLC
License: MIT
EOF
  if [ -f "$ROOT/CHANGELOG.md" ]; then gzip -9n < "$ROOT/CHANGELOG.md" > "$d/changelog.gz"; fi

  # permissions + conffiles + md5sums
  find "$r" -path "$r/DEBIAN" -prune -o -type d -exec chmod 0755 {} +
  find "$r" -path "$r/DEBIAN" -prune -o -type f -exec chmod 0644 {} +
  for x in usr/bin/cigaming usr/lib/cigamingos/firstboot etc/update-motd.d/10-cigamingos; do
    if [ -f "$r/$x" ]; then chmod 0755 "$r/$x"; fi
  done
  for s in preinst postinst prerm postrm; do [ -f "$r/DEBIAN/$s" ] && chmod 0755 "$r/DEBIAN/$s"; done
  chmod 0644 "$r/DEBIAN/control"
  if [ -d "$r/etc" ]; then
    (cd "$r" && find etc -type f | sort | sed 's|^|/|') > "$r/DEBIAN/conffiles"
    chmod 0644 "$r/DEBIAN/conffiles"
  fi
  (cd "$r" && find . -path ./DEBIAN -prune -o -type f -print0 | sort -z | xargs -0 -r md5sum | sed 's|  \./|  |') > "$r/DEBIAN/md5sums"
  size=$(du -sk --exclude=DEBIAN "$r" | cut -f1)
  sed -i "/^Description:/i Installed-Size: $size" "$r/DEBIAN/control"

  dpkg-deb --root-owner-group -Zxz --build "$r" "$OUT/${name}_${VERSION}_all.deb" >/dev/null
done

echo "debs → $OUT"; ls -1 "$OUT"
