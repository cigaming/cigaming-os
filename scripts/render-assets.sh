#!/usr/bin/env bash
# Render every brand asset from branding/*.svg + branding/palette.env.
# Output: build/assets/  (consumed by scripts/build-packages.sh)
# Needs: rsvg-convert (librsvg2-bin), base64
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/build/assets"
# shellcheck source=../branding/palette.env
source "$ROOT/branding/palette.env"

command -v rsvg-convert >/dev/null || { echo "rsvg-convert missing: apt install librsvg2-bin" >&2; exit 1; }

rm -rf "$OUT"; mkdir -p "$OUT"

fill() { # fill <in.svg> <out.svg> — replace {{TOKENS}} with palette values
  sed -e "s|{{NIGHT}}|$NIGHT|g" -e "s|{{PLUM}}|$PLUM|g" -e "s|{{DUSK}}|$DUSK|g" \
      -e "s|{{AMBER}}|$AMBER|g" -e "s|{{MANE}}|$MANE|g" -e "s|{{CREAM}}|$CREAM|g" \
      -e "s|{{TEAL}}|$TEAL|g" -e "s|{{OS_NAME}}|$OS_NAME|g" \
      -e "s|{{LOGO_PATH}}|${LOGO_PATH:-}|g" "$1" > "$2"
}

# Logo
fill "$ROOT/branding/logo.svg" "$OUT/logo.svg"
for s in 16 22 24 32 48 64 128 256 512; do
  rsvg-convert -w "$s" -h "$s" "$OUT/logo.svg" -o "$OUT/logo-$s.png"
done

# Wallpaper (logo embedded so the SVG is self-contained for SDDM/Qt)
LOGO_PATH="data:image/png;base64,$(base64 -w0 "$OUT/logo-512.png")"
export LOGO_PATH
fill "$ROOT/branding/wallpaper.svg" "$OUT/wallpaper.svg"
rsvg-convert -w 3840 -h 2160 "$OUT/wallpaper.svg" -o "$OUT/wallpaper-3840x2160.png"
rsvg-convert -w 1920 -h 1080 "$OUT/wallpaper.svg" -o "$OUT/wallpaper-1920x1080.png"
rsvg-convert -w 1280 -h 1024 --keep-aspect-ratio "$OUT/wallpaper.svg" -o "$OUT/wallpaper-1280x1024.png" || true

# GRUB backgrounds (darker, no text; menu sits on top)
cat > "$OUT/grub.svg" <<EOF
<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 1920 1080">
  <defs><linearGradient id="g" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="$NIGHT"/><stop offset="1" stop-color="$PLUM"/></linearGradient></defs>
  <rect width="1920" height="1080" fill="url(#g)"/>
  <image xlink:href="$LOGO_PATH" x="1560" y="760" width="260" height="260" opacity="0.9"/>
</svg>
EOF
rsvg-convert -w 1920 -h 1080 "$OUT/grub.svg" -o "$OUT/grub-16x9.png"
rsvg-convert -w 1024 -h 768 --keep-aspect-ratio "$OUT/grub.svg" -o "$OUT/grub-4x3.png" || cp "$OUT/grub-16x9.png" "$OUT/grub-4x3.png"
rsvg-convert -w 640 -h 480 "$OUT/grub.svg" -o "$OUT/isolinux-splash.png"

# Calamares installer welcome banner
cat > "$OUT/calamares-welcome.svg" <<EOF
<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 800 300">
  <rect width="800" height="300" rx="24" fill="$PLUM"/>
  <image xlink:href="$LOGO_PATH" x="40" y="40" width="220" height="220"/>
  <text x="290" y="140" font-family="DejaVu Sans" font-weight="bold" font-size="56" fill="$CREAM">$OS_NAME</text>
  <text x="292" y="196" font-family="DejaVu Sans" font-size="28" fill="$AMBER">$OS_VERSION · $OS_CODENAME_PRETTY</text>
</svg>
EOF
rsvg-convert -w 800 -h 300 "$OUT/calamares-welcome.svg" -o "$OUT/calamares-welcome.png"

# Login-screen wallpaper without the name text (the login screen shows the logo instead)
sed '/<text /d' "$OUT/wallpaper.svg" > "$OUT/wallpaper-nologo.svg"
rsvg-convert -w 1920 -h 1080 "$OUT/wallpaper-nologo.svg" -o "$OUT/wallpaper-nologo-1920x1080.png"

# Vendor logo set — replaces Debian's logos on the GDM/SDDM login screens and
# anywhere else that reads /usr/share/images/vendor-logos (same filenames as Debian's).
LOGO_INNER=$(sed -n '/<g transform/,$p' "$OUT/logo.svg" | sed '$d')   # the logo's drawing, minus <svg> wrapper
lockup() { # lockup <out.svg> <with-version: 0|1>
  local w=1150 extra=""
  if [ "$2" = 1 ]; then
    extra="<text x=\"300\" y=\"212\" font-family=\"DejaVu Sans\" font-size=\"56\" fill=\"$AMBER\">$OS_VERSION · $OS_CODENAME_PRETTY</text>"
  fi
  cat > "$1" <<EOF
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 $w 256" width="$w" height="256">
  <g transform="scale(0.5)">$LOGO_INNER</g>
  <text x="296" y="$([ "$2" = 1 ] && echo 140 || echo 170)" font-family="DejaVu Sans" font-weight="bold" font-size="112" fill="$CREAM">$OS_NAME</text>
  $extra
</svg>
EOF
}
mkdir -p "$OUT/vendor-logos"
lockup "$OUT/vendor-logos/logo-text.svg" 0
lockup "$OUT/vendor-logos/logo-text-version.svg" 1
cp "$OUT/logo.svg" "$OUT/vendor-logos/logo.svg"
for h in 64 128 256; do
  rsvg-convert -h "$h" "$OUT/vendor-logos/logo.svg"              -o "$OUT/vendor-logos/logo-$h.png"
  rsvg-convert -h "$h" "$OUT/vendor-logos/logo-text.svg"         -o "$OUT/vendor-logos/logo-text-$h.png"
  rsvg-convert -h "$h" "$OUT/vendor-logos/logo-text-version.svg" -o "$OUT/vendor-logos/logo-text-version-$h.png"
done
# Single-color emblems (file manager "vendor" badge, symbolic icons)
#   symbolic: solid dark silhouette; white: cream cub that keeps its dark eyes + nose
sed -E "s/fill=\"#[0-9a-fA-F]{6}\"/fill=\"$NIGHT\"/g; s/ opacity=\"[0-9.]+\"//g" "$OUT/logo.svg" > "$OUT/vendor-logos/emblem-symbolic.svg"
sed -E -e "s/fill=\"($AMBER|$MANE)\"/fill=\"$CREAM\"/g" -e '/opacity=/d' "$OUT/logo.svg" > "$OUT/vendor-logos/emblem-white.svg"
for name in symbolic white; do
  for s in 64 128 256; do rsvg-convert -w "$s" -h "$s" "$OUT/vendor-logos/emblem-$name.svg" -o "$OUT/vendor-logos/emblem-$name-$s.png"; done
done

echo "assets → $OUT"
