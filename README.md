# qrussell-repo
This is a repository for projects published by qrussell on github.

# Wemo Ops Center Latest
## On Fedora / Rocky Linux (RPM) Desktop App + Server

### Option: 1
### 1. Add the repo
```bash
sudo dnf config-manager --add-repo https://qrussell.github.io/qrussell-repo/qrussell.repo
```
### 2. Install
```bash
sudo dnf install wemo-ops
```

### Option: 2
### 1. Manually add the repo
```bash
sudo tee /etc/yum.repos.d/qrussell.repo <<EOF
[qrussell]
name=Quentin Russell Repo
baseurl=https://qrussell.github.io/qrussell-repo/
enabled=1
gpgcheck=0
skip_if_unavailable=True
EOF
```
### 2. Install
```bash
sudo clean all
sudo dnf makecache
sudo dnf install wemo-ops
```

## On Ubuntu / Debian (DEB) Desktop App + Server
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
baseurl=https://qrussell.github.io/qrussell-repo/
enabled=1
gpgcheck=0
skip_if_unavailable=True
EOF
```
### 2. Install
```bash
sudo clean all
sudo dnf makecache
sudo dnf install wemo-ops-server
```

## On Ubuntu / Debian (DEB) Server Only 
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
sudo apt install wemo-ops-server
```
