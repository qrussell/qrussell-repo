#!/bin/bash

# Stop on errors
set -e

echo "--- 1. Updating RPM Repo (Fedora/Rocky) ---"
# Only run if rpm dir exists
if [ -d "rpm" ]; then
    createrepo --update rpm/
else
    echo "Skipping RPM (directory missing)"
fi

echo "--- 2. Updating DEB Repo (Ubuntu/Debian) ---"
cd deb

# A. Generate the Packages list
dpkg-scanpackages . /dev/null > Packages
gzip -k -f Packages

# B. Generate the Release file with Date and Hashes
# (This fixes the 'No Hash entry' and 'Invalid Date' warnings)
cat > Release <<EOF
Label: QRussell Repo
Archive: stable
Component: main
Architecture: amd64
Date: $(date -uR)
EOF

# Append SHA256 Hashes (The modern standard)
echo "SHA256:" >> Release
for f in Packages Packages.gz; do
    # Calculate hash, size, and filename
    HASH=$(sha256sum "$f" | awk '{print $1}')
    SIZE=$(stat -c%s "$f")
    echo " $HASH $SIZE $f" >> Release
done

# (Optional) Append MD5 Hashes for older systems
echo "MD5Sum:" >> Release
for f in Packages Packages.gz; do
    HASH=$(md5sum "$f" | awk '{print $1}')
    SIZE=$(stat -c%s "$f")
    echo " $HASH $SIZE $f" >> Release
done

cd ..

echo "--- 3. Pushing to GitHub ---"
git add .
git commit -m "Update repo metadata (Fix Release file)"
git push origin main

echo "✅ Done! Metadata updated."