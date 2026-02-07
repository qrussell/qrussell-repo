# qrussell-repo
This is a repository for projects published by qrussell on github.
## On Fedora / Rocky Linux (RPM)

### 1. Add the repo
```bash
sudo dnf config-manager --add-repo https://qrussell.github.io/qrussell-repo/qrussell.repo
```
### 2. Install
```bash
sudo dnf install wemo-ops
sudo dnf install wemo-ops-server
```
## On Ubuntu / Debian (DEB)
Since we aren't using GPG signing (which is complex to set up), we use [trusted=yes].

### 1. Add the repo
```bash
echo "deb [trusted=yes] https://qrussell.github.io/qrussell-repo/deb ./" | sudo tee /etc/apt/sources.list.d/qrussell.list
``` 
### 2. Update
```bash
sudo apt update
# (You should see: "Get:1 https://qrussell.github.io/qrussell-repo/deb ./ InRelease")
```
### 3. Install
```bash
sudo apt install wemo-ops
sudo apt install wemo-ops-server
```
