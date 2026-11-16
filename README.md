# qrussell-repo
This is a repository for projects published by qrussell on github.

# Ubuntu / Debian (DEB): add the repository
The APT repository is signed. Add its key and the repository once:

```bash
sudo curl -fsSL https://qrussell.github.io/qrussell-repo/deb/qrussell-repo.gpg -o /usr/share/keyrings/qrussell-repo.gpg
echo "deb [signed-by=/usr/share/keyrings/qrussell-repo.gpg] https://qrussell.github.io/qrussell-repo/deb ./" | sudo tee /etc/apt/sources.list.d/qrussell.list
sudo apt update
```

The key's fingerprint is `9994A9EB39EB3C101C949FB2012BA14E0FE3A355`. Check the downloaded key with:
```bash
gpg --show-keys /usr/share/keyrings/qrussell-repo.gpg
```

**Already added the repo with `[trusted=yes]`?** Run the commands above. The new line replaces
the old one, and apt then checks that packages really come from this repository.

# RedstonePanel
Web panel to install and manage Minecraft Java and Bedrock servers on Ubuntu 24.04 / 25.04.
Source: https://github.com/qrussell/redstonepanel

## On Ubuntu (DEB)
After adding the repository (above):
```bash
sudo apt install redstonepanel
```
Then open `http://<server>:8080/` and sign in with a Linux account in the `sudo` group.
Hosts that only run Bedrock servers can skip Java: `sudo apt install --no-install-recommends redstonepanel`.

# Wemo Ops Center Latest
## On Fedora / Rocky Linux (RPM) Desktop App + Server

## Option: 1
### 1. Add the repo
```bash
sudo dnf config-manager --add-repo https://qrussell.github.io/qrussell-repo/qrussell.repo
```
### 2. Install
```bash
sudo dnf install wemo-ops
```

## Option: 2
### 1. Manually add the repo
```bash
sudo tee /etc/yum.repos.d/qrussell.repo <<EOF
[qrussell]
name=Quentin Russell Repo
baseurl=https://qrussell.github.io/qrussell-repo/rpm/
enabled=1
gpgcheck=0
skip_if_unavailable=True
EOF
```
### 2. Install
```bash
sudo dnf clean all
sudo dnf makecache
sudo dnf install wemo-ops
```

## On Ubuntu / Debian (DEB) Desktop App + Server
After adding the repository (see the top of this page):
```bash
sudo apt install wemo-ops
```

# Wemo Ops Server v1.0.2
## On Fedora / Rocky Linux (RPM) Server Only

### Option: 1
### 1. Add the repo
```bash
sudo dnf config-manager --add-repo https://qrussell.github.io/qrussell-repo/qrussell.repo
```
### 2. Install
```bash
sudo dnf install wemo-ops-server
```

### Option: 2
### 1. Manually add the repo
```bash
sudo tee /etc/yum.repos.d/qrussell.repo <<EOF
[qrussell]
name=Quentin Russell Repo
baseurl=https://qrussell.github.io/qrussell-repo/rpm/
enabled=1
gpgcheck=0
skip_if_unavailable=True
EOF
```
### 2. Install
```bash
sudo dnf clean all
sudo dnf makecache
sudo dnf install wemo-ops-server
```

## On Ubuntu / Debian (DEB) Server Only
After adding the repository (see the top of this page):
```bash
sudo apt install wemo-ops-server
```

# Maintainer notes
The site is built and deployed by GitHub Actions
(`.github/workflows/publish.yml` → `scripts/build_site.py`). It builds the apt index
(signed) and the RPM indexes (`rpm/repodata`, plus the top-level `repodata` used by
machines set up with `baseurl=.../qrussell-repo/`), then deploys to GitHub Pages.
Indexes and release packages are never committed, so the git history doesn't grow.

- **Release packages (large):** listed in `sources.json`. The newest `keep` published
  releases of each project are downloaded at build time. A new release appears within
  4 hours (scheduled check), or right away with *Actions → Publish repository → Run workflow*.
  Lower `keep` if the build warns that the site is approaching GitHub Pages' 1 GB limit.
- **Other packages (small):** copy the `.deb` into `deb/` or the `.rpm` into `rpm/`, then
  `./update_repo.sh "Add <package> <version>"` (or `.\update_repo.ps1 "..."` from
  PowerShell). It commits and pushes; the push triggers a new build.
- **Local preview:** `PREVIEW=1 ./update_repo.sh` builds an unsigned copy of the site in
  `_site/` (uses Docker when the Linux tools aren't installed).
- **Signing key:** fingerprint in `signing-key.fpr`. CI signs with the private key stored in
  the `github-pages` environment secrets `QRUSSELL_REPO_SIGNING_KEY` (armored private key)
  and `QRUSSELL_REPO_SIGNING_PASSPHRASE`; only workflows on `main` can read them. Keep
  an offline backup of the private key and never commit it. Users trust exactly this key,
  so replacing it (or adding a subkey) requires every user to re-download the public key.
