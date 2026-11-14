#!/bin/bash
# Rebuilds the package indexes, signs the APT index with the repo key, and publishes.
#
#   ./update_repo.sh "Add redstonepanel 1.1.0"
#
# Runs in Git Bash on Windows or on Linux. Tools that Windows doesn't have (dpkg-scanpackages,
# createrepo) run in Docker when they aren't installed. Signing uses your GnuPG key
# (fingerprint in signing-key.fpr, created by new_signing_key.sh) and asks for its passphrase.
# Set NO_PUSH=1 to stop before committing.
set -euo pipefail
cd "$(dirname "$0")"

MSG=${1:-"Update repo metadata"}
KEY=${QRUSSELL_REPO_KEY:-$(tr -d '[:space:]' < signing-key.fpr 2>/dev/null || true)}
[ -n "$KEY" ] || { echo "No signing key: run ./new_signing_key.sh first (or set QRUSSELL_REPO_KEY)." >&2; exit 1; }
gpg --list-secret-keys "$KEY" >/dev/null 2>&1 || { echo "The private key $KEY is not in this GnuPG keyring." >&2; exit 1; }

# Run a command with a Linux tool: natively if installed, otherwise in a container
linux() {   # linux <tool> <docker image> <setup command> <command>
    if command -v "$1" >/dev/null 2>&1; then
        bash -c "$4"
    else
        command -v docker >/dev/null || { echo "$1 is not installed and Docker isn't available." >&2; exit 1; }
        local here; here=$(pwd -W 2>/dev/null || pwd)
        MSYS_NO_PATHCONV=1 docker run --rm -v "$here:/repo" -w /repo "$2" bash -c "$3 >/dev/null 2>&1 && $4"
    fi
}

echo "--- 1. RPM repo (Fedora/Rocky) ---"
if [ -d rpm ] && [ -n "$(git status --porcelain -- 'rpm/*.rpm')" ]; then
    linux createrepo_c fedora:latest "dnf -y -q install createrepo_c" "createrepo_c --update rpm/"
else
    echo "No new or changed .rpm files; RPM index left as is."
fi

echo "--- 2. DEB repo (Ubuntu/Debian) ---"
linux dpkg-scanpackages ubuntu:24.04 "apt-get update -qq && apt-get install -y -qq dpkg-dev" \
      "cd deb && dpkg-scanpackages . /dev/null > Packages"
cd deb
gzip -k -f -n Packages

# Same fields as before (changing Label/Suite makes apt ask existing users to confirm)
cat > Release <<EOF
Label: QRussell Repo
Archive: stable
Component: main
Architecture: amd64
Date: $(date -uR)
EOF
echo "SHA256:" >> Release
for f in Packages Packages.gz; do
    echo " $(sha256sum "$f" | awk '{print $1}') $(stat -c%s "$f") $f" >> Release
done
echo "MD5Sum:" >> Release
for f in Packages Packages.gz; do
    echo " $(md5sum "$f" | awk '{print $1}') $(stat -c%s "$f") $f" >> Release
done

echo "--- 3. Sign (asks for the key's passphrase) ---"
gpg --yes --local-user "$KEY" --clearsign --output InRelease Release
gpg --yes --local-user "$KEY" --detach-sign --output Release.gpg Release
gpg --verify InRelease 2>&1 | grep -E "Good signature|BAD" || { echo "Signature check failed" >&2; exit 1; }
# Public key for users (binary for /usr/share/keyrings, armored to read/compare)
gpg --export "$KEY" > qrussell-repo.gpg
gpg --armor --export "$KEY" > qrussell-repo.asc
cd ..
# Install instructions show the fingerprint so users can check the key they downloaded
sed -i "s/__REPO_KEY_FINGERPRINT__/$KEY/g" README.md index.html

echo "--- 4. Publish ---"
git add -A
git status --short
if [ -n "${NO_PUSH:-}" ]; then
    echo "NO_PUSH set: not committing."
    exit 0
fi
read -r -p "Commit \"$MSG\" and push to GitHub? [y/N] " answer
[[ "$answer" =~ ^[Yy]$ ]] || { echo "Not published (changes are staged)."; exit 0; }
git commit -q -m "$MSG"
git push origin main
echo "✅ Published. GitHub Pages updates within a minute or two."
