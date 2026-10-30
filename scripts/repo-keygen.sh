#!/usr/bin/env bash
# One-time: create the CiGaming OS archive signing key.
#
#   keys/cigamingos-archive.asc          PUBLIC key  → commit this
#   keys/private/cigamingos-archive.sec  PRIVATE key → never commit;
#                                         put it in the GitHub secret REPO_SIGNING_KEY
#                                         and keep an offline backup.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
KEYDIR="${KEYDIR:-$ROOT/keys}"
UID_STR="${KEY_UID:-CiGaming OS Archive Signing Key <admin@snugglesmp.com>}"

if [ -f "$KEYDIR/cigamingos-archive.asc" ] && [ "${FORCE:-0}" != 1 ]; then
  echo "A key already exists at $KEYDIR/cigamingos-archive.asc (FORCE=1 to replace)." >&2
  exit 1
fi

mkdir -p "$KEYDIR/private"; chmod 700 "$KEYDIR/private"
GNUPGHOME="$(mktemp -d)"; export GNUPGHOME
trap 'rm -rf "$GNUPGHOME"' EXIT

# RSA 4096, no passphrase (CI signs unattended), expires in 5 years.
gpg --batch --pinentry-mode loopback --passphrase '' \
    --quick-generate-key "$UID_STR" rsa4096 sign 5y
FPR=$(gpg --list-secret-keys --with-colons | awk -F: '/^fpr:/{print $10; exit}')

gpg --armor --export "$FPR"            > "$KEYDIR/cigamingos-archive.asc"
gpg --armor --export-secret-keys "$FPR" > "$KEYDIR/private/cigamingos-archive.sec"
chmod 600 "$KEYDIR/private/cigamingos-archive.sec"
echo "$FPR" > "$KEYDIR/fingerprint"

cat <<EOF

Key created: $FPR

Next:
  1. git add keys/cigamingos-archive.asc keys/fingerprint
  2. GitHub → repo Settings → Secrets → Actions → New secret
       name:  REPO_SIGNING_KEY
       value: (paste the whole of keys/private/cigamingos-archive.sec)
  3. Back up keys/private/ somewhere offline, then delete it here.
EOF
