#!/bin/bash
echo "--- Updating RPM Repo ---"
createrepo --update rpm/

echo "--- Updating DEB Repo ---"
cd deb
dpkg-scanpackages . /dev/null > Packages
gzip -k -f Packages
echo "Label: QRussell Repo" > Release
echo "Archive: stable" >> Release
echo "Component: main" >> Release
echo "Architecture: amd64" >> Release
cd ..

echo "--- Pushing to GitHub ---"
git add .
git commit -m "Repo update"
git push origin main

echo "Done! Users can update in 5 minutes."
