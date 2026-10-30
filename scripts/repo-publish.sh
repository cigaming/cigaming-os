#!/usr/bin/env bash
# Build the signed, static CiGaming OS apt repo from build/debs/.
# Output: build/repo-public/  — plain files; serve with Caddy, GitHub Pages,
# or anything that can host a folder. No server-side code needed.
#
# Signing key: set REPO_SIGNING_KEY (armored private key, e.g. a CI secret),
# or have the key already in your own GnuPG keyring.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT/build"
PUB="$BUILD/repo-public"
WORK="$BUILD/repo-work"
# shellcheck source=../branding/palette.env
source "$ROOT/branding/palette.env"
REPO_HOST="${REPO_URL#*://}"; REPO_HOST="${REPO_HOST%%/*}"

ls "$BUILD"/debs/*.deb >/dev/null 2>&1 || { echo "No debs — run scripts/build-packages.sh first" >&2; exit 1; }
[ -f "$ROOT/keys/fingerprint" ] || { echo "No keys/fingerprint — run scripts/repo-keygen.sh first" >&2; exit 1; }
FPR="$(tr -d '[:space:]' < "$ROOT/keys/fingerprint")"

if [ -n "${REPO_SIGNING_KEY:-}" ]; then
  GNUPGHOME="$(mktemp -d)"; export GNUPGHOME
  trap 'rm -rf "$GNUPGHOME"' EXIT
  printf '%s\n' "$REPO_SIGNING_KEY" | gpg --batch --import 2>/dev/null
fi
gpg --list-secret-keys "$FPR" >/dev/null 2>&1 || { echo "Private key $FPR not available for signing" >&2; exit 1; }

rm -rf "$WORK" "$PUB"; mkdir -p "$WORK/conf" "$PUB"
sed -e "s|@OS_NAME@|$OS_NAME|g" -e "s|@OS_CODENAME@|$OS_CODENAME|g" -e "s|@OS_VERSION@|$OS_VERSION|g" \
    -e "s|@OS_CODENAME_PRETTY@|$OS_CODENAME_PRETTY|g" -e "s|@DEBIAN_BASE@|$DEBIAN_BASE|g" \
    -e "s|@FINGERPRINT@|$FPR|g" "$ROOT/repo/conf/distributions.in" > "$WORK/conf/distributions"
cp "$ROOT/repo/conf/options" "$WORK/conf/options"

RP=(reprepro -b "$WORK" --outdir "$PUB" --dbdir "$WORK/db")
"${RP[@]}" includedeb "$OS_CODENAME" "$BUILD"/debs/*.deb
"${RP[@]}" export "$OS_CODENAME"

# Extras served next to the repo
cp "$ROOT/keys/cigamingos-archive.asc" "$PUB/cigamingos-archive.asc"
gpg --dearmor < "$ROOT/keys/cigamingos-archive.asc" > "$PUB/cigamingos-archive-keyring.gpg"
sed -e "s|@REPO_URL@|$REPO_URL|g" -e "s|@OS_CODENAME@|$OS_CODENAME|g" -e "s|@OS_NAME@|$OS_NAME|g" \
    -e "s|@DEBIAN_BASE@|$DEBIAN_BASE|g" "$ROOT/scripts/convert.sh" > "$PUB/convert.sh"
sed -e "s|@REPO_URL@|$REPO_URL|g" -e "s|@OS_CODENAME@|$OS_CODENAME|g" -e "s|@OS_NAME@|$OS_NAME|g" \
    -e "s|@DEBIAN_BASE@|$DEBIAN_BASE|g" -e "s|@FINGERPRINT@|$FPR|g" \
    -e "s|@AMBER@|$AMBER|g" -e "s|@NIGHT@|$NIGHT|g" -e "s|@PLUM@|$PLUM|g" -e "s|@CREAM@|$CREAM|g" \
    "$ROOT/repo/index.html" > "$PUB/index.html"
cp "$BUILD/assets/logo-128.png" "$PUB/logo.png" 2>/dev/null || true
echo "$REPO_HOST" > "$PUB/CNAME"      # GitHub Pages custom domain
touch "$PUB/.nojekyll"

echo "repo → $PUB"
"${RP[@]}" list "$OS_CODENAME"
