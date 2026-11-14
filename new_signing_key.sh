#!/bin/bash
# One-time: creates the GnuPG key that signs this repository's APT index.
#   ./new_signing_key.sh
# GnuPG asks you for a passphrase; choose a strong one and keep it safe.
set -euo pipefail
cd "$(dirname "$0")"

if [ -s signing-key.fpr ]; then
    echo "signing-key.fpr already names a key: $(cat signing-key.fpr)" >&2
    echo "Delete that file first if you really want a new key (users would need the new public key)." >&2
    exit 1
fi

UID_NAME="QRussell Repo Signing Key"
gpg --quick-generate-key "$UID_NAME" ed25519 sign 5y
FPR=$(gpg --list-keys --with-colons "$UID_NAME" | awk -F: '/^fpr:/ {print $10; exit}')
echo "$FPR" > signing-key.fpr

cat <<EOF

Created signing key $FPR (expires in 5 years).
Its fingerprint is saved in signing-key.fpr; update_repo.sh uses it.

BACK UP THE PRIVATE KEY now, somewhere off this PC (e.g. a password manager or USB stick):
  gpg --export-secret-keys --armor $FPR > qrussell-repo-signing-key.private.asc
Never commit that file. Without it you can't publish signed updates if this PC is lost.
EOF
