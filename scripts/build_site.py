#!/usr/bin/env python3
"""Build the package repository site into _site/ (deployed to GitHub Pages by
.github/workflows/publish.yml).

    python3 scripts/build_site.py              # build and sign (key from signing-key.fpr)
    python3 scripts/build_site.py --no-sign    # build only, e.g. to test locally

Packages come from two places:
  * committed files in deb/ and rpm/ (small packages), and
  * GitHub release assets of the projects in sources.json (large packages). These
    are downloaded here and never committed, so the git history doesn't grow.

Generated (never committed): deb/Packages, Packages.gz, Release, InRelease,
Release.gpg, rpm/repodata/ and the top-level repodata/ (for machines set up with
baseurl=.../qrussell-repo/ by older instructions; its entries point into rpm/).

Needs: dpkg-scanpackages (dpkg-dev), createrepo_c, gpg. Signing passphrase is
read from the QRUSSELL_REPO_PASSPHRASE environment variable when set.
"""
import argparse
import email.utils
import fnmatch
import glob
import gzip
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SITE = os.path.join(ROOT, "_site")
CACHE = os.path.join(ROOT, ".cache", "release-assets")
# Static files served as-is
STATIC = ["index.html", "README.md", "qrussell.repo", "signing-key.fpr", ".nojekyll",
          "deb/qrussell-repo.gpg", "deb/qrussell-repo.asc"]
PAGES_LIMIT = 1_000_000_000      # GitHub Pages refuses sites over 1 GB
WARN_AT = 800_000_000


def log(msg):
    print(msg, flush=True)


def run(cmd, **kw):
    log("   $ " + " ".join(cmd))
    subprocess.run(cmd, check=True, **kw)


def gh_api(path):
    req = urllib.request.Request("https://api.github.com" + path,
                                 headers={"Accept": "application/vnd.github+json"})
    token = os.environ.get("GITHUB_TOKEN")
    if token:
        req.add_header("Authorization", "Bearer " + token)
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.load(r)


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def download(url, dest, size):
    if os.path.exists(dest) and os.path.getsize(dest) == size:
        log(f"   cached {os.path.basename(dest)}")
        return
    log(f"   downloading {os.path.basename(dest)} ({size / 1e6:.1f} MB)")
    tmp = dest + ".part"
    with urllib.request.urlopen(url, timeout=600) as r, open(tmp, "wb") as f:
        shutil.copyfileobj(r, f, 1 << 20)
    if os.path.getsize(tmp) != size:
        sys.exit(f"ERROR: {url}: expected {size} bytes, got {os.path.getsize(tmp)}")
    os.replace(tmp, dest)


def release_packages():
    """Yield (subdir, filename, local_path) for release assets to publish."""
    with open(os.path.join(ROOT, "sources.json"), encoding="utf-8") as f:
        sources = json.load(f)["sources"]
    os.makedirs(CACHE, exist_ok=True)
    for src in sources:
        pattern = re.compile(src.get("tag_pattern", ".*"))
        releases = [r for r in gh_api(f"/repos/{src['repo']}/releases?per_page=50")
                    if not r["draft"] and not r["prerelease"] and pattern.match(r["tag_name"])]
        releases.sort(key=lambda r: r["published_at"], reverse=True)
        chosen = releases[:src.get("keep", 2)]
        log(f"-- {src['repo']}: {', '.join(r['tag_name'] for r in chosen) or 'no releases'}")
        for rel in chosen:
            for asset in rel["assets"]:
                name = asset["name"]
                sub = "deb" if fnmatch.fnmatch(name, "*.deb") else "rpm" if fnmatch.fnmatch(name, "*.rpm") else None
                if not sub:
                    continue
                dest = os.path.join(CACHE, name)
                download(asset["browser_download_url"], dest, asset["size"])
                yield sub, name, dest


def link_or_copy(src, dest):
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    try:
        os.link(src, dest)
    except OSError:
        shutil.copy2(src, dest)


def build_deb_index(deb_dir):
    # --multiversion: keep every .deb. Without it, packages with the same name and
    # version (amd64 + arm64 builds) collapse to one entry and ARM64 gets amd64.
    with open(os.path.join(deb_dir, "Packages"), "wb") as out:
        subprocess.run(["dpkg-scanpackages", "--multiversion", ".", "/dev/null"],
                       cwd=deb_dir, stdout=out, check=True)
    with open(os.path.join(deb_dir, "Packages"), "rb") as src, \
            gzip.GzipFile(os.path.join(deb_dir, "Packages.gz"), "wb", mtime=0) as dst:
        shutil.copyfileobj(src, dst)
    files = ["Packages", "Packages.gz"]
    # Same fields as before: changing Label/Suite would make apt ask users to confirm
    lines = ["Label: QRussell Repo", "Archive: stable", "Component: main",
             "Architecture: amd64", "Date: " + email.utils.formatdate(usegmt=True), "SHA256:"]
    for name in files:
        p = os.path.join(deb_dir, name)
        lines.append(f" {sha256(p)} {os.path.getsize(p)} {name}")
    lines.append("MD5Sum:")
    for name in files:
        p = os.path.join(deb_dir, name)
        lines.append(f" {hashlib.md5(open(p, 'rb').read()).hexdigest()} {os.path.getsize(p)} {name}")
    with open(os.path.join(deb_dir, "Release"), "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines) + "\n")


def sign_deb_index(deb_dir, key):
    passphrase = os.environ.get("QRUSSELL_REPO_PASSPHRASE")
    base = ["gpg", "--batch", "--yes", "--local-user", key]
    kw = {}
    if passphrase is not None:
        base += ["--pinentry-mode", "loopback", "--passphrase-fd", "0"]
        kw = {"input": passphrase.encode()}
    rel = os.path.join(deb_dir, "Release")
    run(base + ["--clearsign", "--output", os.path.join(deb_dir, "InRelease"), rel], **kw)
    run(base + ["--detach-sign", "--output", os.path.join(deb_dir, "Release.gpg"), rel], **kw)
    out = subprocess.run(["gpg", "--verify", os.path.join(deb_dir, "InRelease")],
                         capture_output=True, text=True)
    if "Good signature" not in out.stderr:
        sys.exit("ERROR: InRelease signature check failed:\n" + out.stderr)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--no-sign", action="store_true", help="skip signing (local testing)")
    args = ap.parse_args()

    if os.path.isdir(SITE):
        shutil.rmtree(SITE)
    os.makedirs(os.path.join(SITE, "deb"))
    os.makedirs(os.path.join(SITE, "rpm"))

    log("--- 1. Static files")
    for rel in STATIC:
        src = os.path.join(ROOT, rel)
        if os.path.exists(src):
            link_or_copy(src, os.path.join(SITE, rel))

    log("--- 2. Packages")
    names = {}
    for sub in ("deb", "rpm"):
        for p in sorted(glob.glob(os.path.join(ROOT, sub, "*." + sub))):
            names[(sub, os.path.basename(p))] = p
    committed = len(names)
    for sub, name, path in release_packages():
        names.setdefault((sub, name), path)   # a committed file wins over a release asset
    for (sub, name), path in sorted(names.items()):
        link_or_copy(path, os.path.join(SITE, sub, name))
    log(f"   {committed} committed + {len(names) - committed} from releases")

    log("--- 3. APT index")
    build_deb_index(os.path.join(SITE, "deb"))

    log("--- 4. RPM indexes (rpm/ and top level)")
    run(["createrepo_c", "--quiet", os.path.join(SITE, "rpm")])
    run(["createrepo_c", "--quiet", "--excludes", "deb/*", SITE])

    if args.no_sign:
        log("--- 5. Signing skipped (--no-sign)")
    else:
        log("--- 5. Sign APT index")
        key = os.environ.get("QRUSSELL_REPO_KEY")
        if not key:
            with open(os.path.join(ROOT, "signing-key.fpr"), encoding="utf-8") as f:
                key = f.read().strip()
        sign_deb_index(os.path.join(SITE, "deb"), key)

    # Manifest of the content (not timestamps), so scheduled runs can skip deploying
    # when nothing changed
    entries = []
    for dirpath, _, files in os.walk(SITE):
        for fn in files:
            rel = os.path.relpath(os.path.join(dirpath, fn), SITE).replace(os.sep, "/")
            if rel.startswith(("deb/Release", "deb/InRelease")) or "repodata/" in rel or rel == "manifest.txt":
                continue
            entries.append(f"{sha256(os.path.join(dirpath, fn))}  {rel}")
    with open(os.path.join(SITE, "manifest.txt"), "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(sorted(entries)) + "\n")

    total = sum(os.path.getsize(os.path.join(d, fn)) for d, _, fs in os.walk(SITE) for fn in fs)
    log(f"--- Site size: {total / 1e6:.0f} MB")
    if total > PAGES_LIMIT:
        sys.exit("ERROR: site is over GitHub Pages' 1 GB limit; lower 'keep' in sources.json")
    if total > WARN_AT:
        log("WARNING: site is over 800 MB; consider lowering 'keep' in sources.json")


if __name__ == "__main__":
    main()
