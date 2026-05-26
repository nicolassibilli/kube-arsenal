# Kubernetes Administration Workstation Bootstrap

![Shell](https://img.shields.io/badge/shell-bash-blue)
![Platform](https://img.shields.io/badge/platform-Ubuntu%20%7C%20Debian%20%7C%20WSL2-green)
![Version](https://img.shields.io/badge/version-v1.0.0-lightgrey)

## Overview

`install-k8s-admin-workstation.sh` is an idempotent bootstrap script used to install, configure, and validate a Kubernetes administration workstation.

It is designed for Cloud, DevOps, SRE, and Kubernetes administration workflows where a local CLI environment must provide the right balance between daily operations, troubleshooting, manifest validation, security scanning, secrets handling, and policy-as-code tooling.

The script provides two main execution modes:

- `--install` / `-i`: install and configure the validated workstation toolchain.
- `--check` / `-c`: check installed binaries, versions, `kubectl` plugins, and display a categorized summary.

Without arguments, the script prints its built-in help.

---

## Target environment

The script is optimized for:

- Ubuntu
- Debian
- WSL2
- zsh or bash

The default shell configuration target is:

```bash
$HOME/.zshrc
```

This can be overridden with the `SHELL_RC` environment variable.

---

## Installed toolchain

The install mode provisions the following tools.

### Core Kubernetes tools

| Tool | Purpose |
|---|---|
| `kubectl` | Main Kubernetes CLI |
| `helm` | Kubernetes package manager |
| `kustomize` | Kubernetes manifest customization |
| `k9s` | Terminal UI for Kubernetes |
| `stern` | Multi-pod log tailing |
| `kubectx` | Fast Kubernetes context switching |
| `kubens` | Fast Kubernetes namespace switching |

### Local cluster and container tools

| Tool | Purpose |
|---|---|
| `kind` | Kubernetes in Docker |
| `docker` | Docker CLI / Docker Desktop integration check |

Docker is not installed by default unless explicitly requested with `INSTALL_DOCKER=true`.

### Productivity tools

| Tool | Purpose |
|---|---|
| `jq` | JSON processing |
| `yq` | YAML processing using Mike Farah `yq` |
| `fzf` | Fuzzy finder |
| `bat` / `batcat` | Better file viewer |
| `ripgrep` / `rg` | Fast recursive search |
| `tree` | Directory tree display |
| `watch` | Repeated command execution |
| `curl` | HTTP client |
| `wget` | File downloader |
| `git` | Version control |
| `unzip` | Archive extraction |
| `tar` | Archive management |

### Manifest validation and quality

| Tool | Purpose |
|---|---|
| `kubeconform` | Kubernetes manifest validation |
| `kube-score` | Kubernetes best-practice scoring |
| `pluto` | Deprecated Kubernetes API detection |
| `kubent` | Deprecated Kubernetes API detection |
| `conftest` | OPA/Rego policy testing |
| `opa` | Open Policy Agent CLI |
| `kyverno` | Kyverno CLI for Kubernetes-native policies |

### Security, vulnerability scanning, and SBOM

| Tool | Purpose |
|---|---|
| `trivy` | Vulnerability, IaC, container image, and Kubernetes scanning |
| `grype` | Vulnerability scanning |
| `syft` | SBOM generation |

### Secrets and encryption

| Tool | Purpose |
|---|---|
| `sops` | Secrets encryption |
| `age` | Modern file encryption |
| `age-keygen` | Age key generation |
| `kubeseal` | Sealed Secrets CLI |

### Kubectl plugin ecosystem

The script installs `krew` and the following plugins:

| Plugin | Purpose |
|---|---|
| `neat` | Clean Kubernetes YAML output |
| `tree` | Display Kubernetes resource ownership trees |
| `who-can` | RBAC permission discovery |
| `ctx` | Context switching plugin |
| `ns` | Namespace switching plugin |
| `sniff` | Packet capture plugin |

---

## Usage

### Display help

```bash
./install-k8s-admin-workstation.sh
```

or:

```bash
./install-k8s-admin-workstation.sh --help
```

### Install and configure the workstation

```bash
chmod +x install-k8s-admin-workstation.sh
./install-k8s-admin-workstation.sh --install
```

Short form:

```bash
./install-k8s-admin-workstation.sh -i
```

### Check installed tools

```bash
./install-k8s-admin-workstation.sh --check
```

Short form:

```bash
./install-k8s-admin-workstation.sh -c
```

---

## Environment variables

| Variable | Default | Description |
|---|---|---|
| `INSTALL_DOCKER` | `false` | When set to `true`, installs `docker.io` if Docker is missing |
| `INSTALL_DIR` | `/usr/local/bin` | Target directory for binaries installed from release archives |
| `SHELL_RC` | `$HOME/.zshrc` | Shell configuration file updated by install mode |

Example:

```bash
INSTALL_DOCKER=true ./install-k8s-admin-workstation.sh --install
```

Example with a custom shell configuration file:

```bash
SHELL_RC="$HOME/.bashrc" ./install-k8s-admin-workstation.sh --install
```

---

## Docker and WSL2 note

On WSL2, Docker Desktop with WSL integration is recommended.

By default, the script does not install Docker if the `docker` binary is missing. This avoids replacing or conflicting with a Docker Desktop based setup.

To force Linux-side Docker installation:

```bash
INSTALL_DOCKER=true ./install-k8s-admin-workstation.sh --install
```

---

## Shell configuration

Install mode writes a managed block into the configured shell RC file.

Default target:

```bash
~/.zshrc
```

The block is delimited by:

```bash
# >>> k8s-admin-workstation managed block >>>
# <<< k8s-admin-workstation managed block <<<
```

If the block already exists, it is replaced cleanly. This prevents duplicate aliases or functions after repeated executions.

The managed block configures:

- `KUBE_EDITOR`
- `KREW_ROOT` path integration
- `kubectl` completion
- `helm` completion
- optional `kubectx` and `kubens` completion
- Kubernetes aliases
- Helm/K9s/Stern aliases
- manifest validation helpers
- policy testing helpers
- deprecated API detection helpers
- Debian/Ubuntu `batcat` compatibility alias

After installation, reload your shell:

```bash
source ~/.zshrc
```

---

## Included aliases and helper functions

### Core aliases

```bash
k='kubectl'
kg='kubectl get'
kd='kubectl describe'
ka='kubectl apply -f'
kdel='kubectl delete'
ke='kubectl edit'
kl='kubectl logs'
klf='kubectl logs -f'
kex='kubectl exec -it'
kpf='kubectl port-forward'
kctx='kubectx'
kns='kubens'
```

### Common Kubernetes resources

```bash
kgn='kubectl get nodes'
kgp='kubectl get pods'
kgpa='kubectl get pods -A'
kgs='kubectl get svc'
kgsa='kubectl get svc -A'
kgd='kubectl get deploy'
kgda='kubectl get deploy -A'
kging='kubectl get ingress'
kginga='kubectl get ingress -A'
kgcm='kubectl get configmap'
kgsec='kubectl get secret'
kgns='kubectl get ns'
kgev='kubectl get events --sort-by=.lastTimestamp'
kgeva='kubectl get events -A --sort-by=.lastTimestamp'
```

### Troubleshooting helpers

```bash
kwhere
ksecret-decode <secret-name> <key>
krestart <deployment-name>
klog-label <label-selector>
kpf-svc <service-name> <local-port> <remote-port>
kstern <label-selector>
ksternA <label-selector>
```

### Validation and security helpers

```bash
kval <path>
kscore <path>
kscan-config <path>
```

### Policy helpers

```bash
kpolicy-test <resource-file-or-directory>
kyverno-test <policy-file> <resource-file>
```

### Deprecated API checks

```bash
kdeprecated
kdeprecated-pluto
kdeprecated-helm
kdeprecated-files <directory>
kdeprecated-kubent
```

---

## Check mode

The check mode prints a categorized inventory of the workstation tools.

```bash
./install-k8s-admin-workstation.sh --check
```

It validates:

- binary presence
- basic version output
- Docker CLI presence
- `kubectl krew`
- installed `kubectl` plugins
- `bat` / `batcat` compatibility

The output is grouped by category:

- Core Kubernetes Tools
- Context and Namespace Switching
- Local Cluster and Container Tools
- Productivity CLI Tools
- Kubernetes Manifest Validation and Quality
- Security, Vulnerability Scanning and SBOM
- Secrets and Encryption
- GitOps and Delivery
- Networking, Ingress and Service Mesh
- Certificates, Backup and Cluster Internals
- Kubectl Plugin Manager and Plugins
- Summary

Some tools are intentionally reported as missing when they are outside the selected workstation baseline, for example:

- `argocd`
- `flux`
- `helmfile`
- `skaffold`
- `tilt`
- `cilium`
- `hubble`
- `istioctl`
- `linkerd`
- `cmctl`
- `velero`
- `etcdctl`

These are stack-specific and can be installed later if needed.

---

## Example workflow

### 1. Install the toolchain

```bash
./install-k8s-admin-workstation.sh --install
```

### 2. Reload shell configuration

```bash
source ~/.zshrc
```

### 3. Validate installation

```bash
./install-k8s-admin-workstation.sh --check
```

### 4. Validate Kubernetes manifests

```bash
kval ./manifests
kscore ./manifests
kscan-config ./manifests
```

### 5. Check deprecated APIs

```bash
kdeprecated
```

### 6. Follow logs by label

```bash
kstern app=my-app
```

---

## Testing in a Docker container

The script can be tested inside an Ubuntu container to validate installation flow and binary availability.

Example:

```bash
docker run --rm -it \
  -v "$PWD/install-k8s-admin-workstation.sh:/tmp/install-k8s-admin-workstation.sh:ro" \
  ubuntu:24.04 \
  bash
```

Inside the container:

```bash
apt-get update
apt-get install -y sudo ca-certificates curl wget git gnupg lsb-release jq

useradd -m -s /bin/bash testuser
echo "testuser ALL=(ALL) NOPASSWD:ALL" >/etc/sudoers.d/testuser
chmod 0440 /etc/sudoers.d/testuser

su - testuser
cp /tmp/install-k8s-admin-workstation.sh ~/
chmod +x ~/install-k8s-admin-workstation.sh

INSTALL_DOCKER=false SHELL_RC="$HOME/.zshrc" ~/install-k8s-admin-workstation.sh --install
~/install-k8s-admin-workstation.sh --check
```

This validates:

- dependency installation
- GitHub release downloads
- binary installation into `/usr/local/bin`
- `krew` installation
- `kubectl` plugin installation
- shell configuration block injection
- version checks

It does not validate access to a real Kubernetes cluster.

---

## Idempotency

The script is designed to be re-run safely.

Repeated executions will:

- skip or overwrite binaries as appropriate
- avoid duplicate shell configuration blocks
- preserve a single managed shell block
- reinstall or update release-based binaries
- keep `krew` plugins available in the current non-interactive script execution

---

## Limitations

This script does not configure:

- Kubernetes cluster access
- kubeconfig files
- cloud provider authentication
- Docker Desktop itself
- GitOps controllers inside a cluster
- cert-manager
- Velero server-side components
- service mesh control planes

It installs and configures the local CLI workstation only.

---

## License

This project is licensed under the MIT License.
See the [LICENSE](LICENSE) file for details.

---

## Maintainer notes

This script was built from a validated Kubernetes administration workstation baseline and tested with:

- local workstation execution
- Docker container execution
- integrated check mode
- `kubectl krew` plugin path reload
- managed `.zshrc` block replacement
