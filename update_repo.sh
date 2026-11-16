#!/bin/bash
# Publishes changes to this repository. The site itself (indexes, signing, and the
# release packages listed in sources.json) is built by GitHub Actions on every push
# (.github/workflows/publish.yml), so this only commits and pushes.
#
#   ./update_repo.sh "Add redstonepanel 1.4.0"   # after copying a package into deb/ or rpm/
#   PREVIEW=1 ./update_repo.sh                   # build an unsigned copy of the site in _site/
#
# Runs in Git Bash on Windows or on Linux.
set -euo pipefail
cd "$(dirname "$0")"

if [ -n "${PREVIEW:-}" ]; then
    echo "--- Building an unsigned preview in _site/ ---"
    if command -v dpkg-scanpackages >/dev/null && command -v createrepo_c >/dev/null; then
        python3 scripts/build_site.py --no-sign
    else
        command -v docker >/dev/null || { echo "Needs dpkg-scanpackages + createrepo_c, or Docker." >&2; exit 1; }
        here=$(pwd -W 2>/dev/null || pwd)
        MSYS_NO_PATHCONV=1 docker run --rm -v "$here:/repo" -w /repo ubuntu:24.04 bash -c \
            "apt-get update -qq >/dev/null && apt-get install -y -qq dpkg-dev createrepo-c python3 ca-certificates >/dev/null 2>&1 && python3 scripts/build_site.py --no-sign"
    fi
    exit 0
fi

MSG=${1:-"Update repository"}
git add -A
git status --short
if git diff --cached --quiet; then
    echo "Nothing to publish."
    exit 0
fi
read -r -p "Commit \"$MSG\" and push to GitHub? [y/N] " answer
[[ "$answer" =~ ^[Yy]$ ]] || { echo "Not published (changes are staged)."; exit 0; }
git commit -q -m "$MSG"
git push origin main
echo "✅ Pushed. GitHub Actions builds and deploys the site (Actions tab); Pages updates in a few minutes."
