#!/usr/bin/env bash
# =============================================================================
# kube-arsenal - Kubernetes Administration Workstation Toolkit
# Version: v1.0.0
# =============================================================================
# Purpose:
#   Install, configure, and validate a Kubernetes administration workstation
#   with essential DevOps, security, policy, troubleshooting, and productivity
#   CLI tools.
#
# Target:
#   Ubuntu / Debian / WSL2 with zsh or bash.
#
# Installed tools:
#   kubectl, helm, kustomize, k9s, stern, kubectx, kubens, kind, docker CLI,
#   jq, yq, fzf, bat/batcat, ripgrep, tree, watch, curl, wget, git, unzip, tar,
#   kubeconform, kube-score, pluto, kubent, conftest, opa, kyverno,
#   trivy, grype, syft, sops, age, age-keygen, kubeseal,
#   kubectl krew + plugins: neat, tree, who-can, ctx, ns, sniff.
#
# Modes:
#   -i, --install  Install and configure the kube-arsenal workstation toolkit.
#   -c, --check    Check installed tools and versions.
#   -h, --help     Display usage help.
#
# Notes:
#   - This script is designed to be idempotent.
#   - Docker Desktop with WSL integration is preferred on Windows/WSL2. This script
#     installs docker.io only when Docker is missing and INSTALL_DOCKER=true.
# =============================================================================

set -euo pipefail

# -----------------------------------------------------------------------------
# Config
# -----------------------------------------------------------------------------

INSTALL_DOCKER="${INSTALL_DOCKER:-false}"
INSTALL_DIR="${INSTALL_DIR:-/usr/local/bin}"
SHELL_RC="${SHELL_RC:-$HOME/.zshrc}"
TMP_DIR="$(mktemp -d)"

# -----------------------------------------------------------------------------
# Output colors
# -----------------------------------------------------------------------------

GREEN="\033[0;32m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
BLUE="\033[0;34m"
NC="\033[0m"

# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------

log() {
  echo
  echo "==> $*"
}

warn() {
  echo
  echo "[WARN] $*" >&2
}

fail() {
  echo
  echo "[ERROR] $*" >&2
  exit 1
}

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

require_cmd() {
  local cmd="$1"
  command -v "$cmd" >/dev/null 2>&1 || fail "Required command not found: $cmd"
}

install_binary() {
  local source_path="$1"
  local target_name="$2"

  sudo install -m 755 "$source_path" "$INSTALL_DIR/$target_name"
}

github_latest_tag() {
  local repo="$1"
  curl -fsSL "https://api.github.com/repos/${repo}/releases/latest" | jq -r '.tag_name'
}

already_installed() {
  local cmd="$1"
  command -v "$cmd" >/dev/null 2>&1
}

append_once() {
  local line="$1"
  local file="$2"

  touch "$file"
  grep -qxF "$line" "$file" || echo "$line" >> "$file"
}

reload_shell_rc() {
  # Source the target shell rc inside the current script when possible.
  # This is mainly useful for newly added PATH entries such as Krew.
  if [ -f "$SHELL_RC" ]; then
    # shellcheck disable=SC1090
    set +u
    source "$SHELL_RC" || true
    set -u
  fi
}


# -----------------------------------------------------------------------------
# Usage and mode selection
# -----------------------------------------------------------------------------

show_help() {
  cat <<'EOF'
SYNOPSIS
  kube-arsenal.sh [OPTIONS]

DESCRIPTION
  Install, configure, and validate kube-arsenal, a Kubernetes administration
  workstation toolkit for DevOps, security, policy, troubleshooting, and
  productivity workflows.

OPTIONS
  -i, --install
      Install and configure the kube-arsenal workstation toolkit.

  -c, --check
      Check installed tools, versions, kubectl plugins, and display a summary.

  -h, --help
      Display this help message.

ENVIRONMENT VARIABLES
  INSTALL_DOCKER
      Defaults to false.
      When set to true, installs docker.io if Docker is missing.
      On WSL2, Docker Desktop with WSL integration is recommended instead.

  INSTALL_DIR
      Defaults to /usr/local/bin.
      Target directory used for binaries installed from release archives.

  SHELL_RC
      Defaults to $HOME/.zshrc.
      Shell configuration file updated by install mode.

EXAMPLES
  ./kube-arsenal.sh --install
  ./kube-arsenal.sh --check
  INSTALL_DOCKER=true ./kube-arsenal.sh -i
EOF
}

# -----------------------------------------------------------------------------
# Check mode helpers
# -----------------------------------------------------------------------------

CHECK_OK_COUNT=0
CHECK_MISSING_COUNT=0
CHECK_WARN_COUNT=0

check_print_section() {
  echo
  echo -e "${BLUE}=============================================================================${NC}"
  echo -e "${BLUE} $1${NC}"
  echo -e "${BLUE}=============================================================================${NC}"
}

check_tool() {
  local tool="$1"
  local version_cmd="$2"
  local note="${3:-}"

  if command -v "$tool" >/dev/null 2>&1; then
    echo -e "${GREEN}[OK]${NC} $tool installed"
    if [ -n "$version_cmd" ]; then
      eval "$version_cmd" 2>/dev/null | head -n 5 || true
    fi
    [ -n "$note" ] && echo "Note: $note"
    CHECK_OK_COUNT=$((CHECK_OK_COUNT + 1))
  else
    echo -e "${RED}[MISSING]${NC} $tool not found"
    [ -n "$note" ] && echo "Note: $note"
    CHECK_MISSING_COUNT=$((CHECK_MISSING_COUNT + 1))
  fi

  echo
}

check_alternative_tool() {
  local primary="$1"
  local alternative="$2"
  local primary_version_cmd="$3"
  local alternative_version_cmd="$4"
  local note="${5:-}"

  if command -v "$primary" >/dev/null 2>&1; then
    echo -e "${GREEN}[OK]${NC} $primary installed"
    eval "$primary_version_cmd" 2>/dev/null | head -n 5 || true
    CHECK_OK_COUNT=$((CHECK_OK_COUNT + 1))
  elif command -v "$alternative" >/dev/null 2>&1; then
    echo -e "${YELLOW}[WARN]${NC} $primary not found, but $alternative is installed"
    eval "$alternative_version_cmd" 2>/dev/null | head -n 5 || true
    [ -n "$note" ] && echo "Note: $note"
    CHECK_WARN_COUNT=$((CHECK_WARN_COUNT + 1))
  else
    echo -e "${RED}[MISSING]${NC} $primary / $alternative not found"
    [ -n "$note" ] && echo "Note: $note"
    CHECK_MISSING_COUNT=$((CHECK_MISSING_COUNT + 1))
  fi

  echo
}

check_kubectl_plugin() {
  local plugin="$1"
  local test_cmd="$2"
  local note="${3:-}"

  if kubectl "$plugin" --help >/dev/null 2>&1 || eval "$test_cmd" >/dev/null 2>&1; then
    echo -e "${GREEN}[OK]${NC} kubectl $plugin plugin available"
    [ -n "$note" ] && echo "Note: $note"
    CHECK_OK_COUNT=$((CHECK_OK_COUNT + 1))
  else
    echo -e "${RED}[MISSING]${NC} kubectl $plugin plugin not found"
    [ -n "$note" ] && echo "Note: $note"
    CHECK_MISSING_COUNT=$((CHECK_MISSING_COUNT + 1))
  fi

  echo
}

run_check() {
  # Make Krew plugins available even when the shell rc has not been sourced.
  export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"

  CHECK_OK_COUNT=0
  CHECK_MISSING_COUNT=0
  CHECK_WARN_COUNT=0

  echo "== Kubernetes administration workstation tools check =="
  echo "Date: $(date)"
  echo "Host: $(hostname)"
  echo "Shell: ${SHELL:-unknown}"
  echo

  check_print_section "Core Kubernetes Tools"

  check_tool "kubectl" "kubectl version --client=true" "Main Kubernetes CLI."
  check_tool "helm" "helm version" "Kubernetes package manager."
  check_tool "kustomize" "kustomize version" "Manifest customization tool."
  check_tool "k9s" "k9s version" "Terminal UI for Kubernetes."
  check_tool "stern" "stern --version" "Multi-pod log tailing."

  check_print_section "Context and Namespace Switching"

  check_tool "kubectx" "kubectx --help" "Fast Kubernetes context switching."
  check_tool "kubens" "kubens --help" "Fast Kubernetes namespace switching."

  check_print_section "Local Cluster and Container Tools"

  check_tool "kind" "kind version" "Kubernetes in Docker."
  check_tool "minikube" "minikube version" "Local Kubernetes cluster."
  check_tool "k3d" "k3d version" "K3s in Docker."
  check_tool "docker" "docker version --format 'Client: {{.Client.Version}}'" "Docker client."
  check_tool "nerdctl" "nerdctl --version" "Docker-compatible CLI for containerd."
  check_tool "crictl" "crictl --version" "CRI troubleshooting CLI."

  check_print_section "Productivity CLI Tools"

  check_tool "jq" "jq --version" "JSON processor."
  check_tool "yq" "yq --version" "YAML processor. Mike Farah yq v4.x is recommended."
  check_tool "fzf" "fzf --version" "Fuzzy finder."
  check_alternative_tool "bat" "batcat" "bat --version" "batcat --version" "On Debian/Ubuntu, bat is often installed as batcat. You can add: alias bat='batcat'"
  check_tool "rg" "rg --version" "ripgrep search tool."
  check_tool "tree" "tree --version" "Directory tree viewer."
  check_tool "watch" "watch --version" "Repeated command execution."
  check_tool "curl" "curl --version" "HTTP client."
  check_tool "wget" "wget --version" "File downloader."
  check_tool "git" "git --version" "Version control."
  check_tool "unzip" "unzip -v" "Archive extraction."
  check_tool "tar" "tar --version" "Archive tool."

  check_print_section "Kubernetes Manifest Validation and Quality"

  check_tool "kubeconform" "kubeconform -v" "Fast Kubernetes manifest validator."
  check_tool "kube-score" "kube-score version" "Kubernetes object best-practices scoring."
  check_tool "pluto" "pluto version" "Deprecated Kubernetes API detector."
  check_tool "kubent" "kubent --version" "Kube No Trouble, deprecated API detector."
  check_tool "conftest" "conftest --version" "OPA/Rego policy testing."
  check_tool "opa" "opa version" "Open Policy Agent CLI."
  check_tool "kyverno" "kyverno version" "Kyverno CLI."

  check_print_section "Security, Vulnerability Scanning and SBOM"

  check_tool "trivy" "trivy --version" "Vulnerability, IaC and Kubernetes scanner."
  check_tool "grype" "grype version" "Vulnerability scanner."
  check_tool "syft" "syft version" "SBOM generator."

  check_print_section "Secrets and Encryption"

  check_tool "sops" "sops --version" "Secrets encryption tool."
  check_tool "age" "age --version" "Modern encryption tool."
  check_tool "age-keygen" "age-keygen --version" "Age key generator."
  check_tool "kubeseal" "kubeseal --version" "Sealed Secrets CLI."

  check_print_section "GitOps and Delivery"

  check_tool "argocd" "argocd version --client" "Argo CD CLI."
  check_tool "flux" "flux --version" "Flux CD CLI."
  check_tool "helmfile" "helmfile --version" "Declarative Helm release orchestration."
  check_tool "skaffold" "skaffold version" "Kubernetes development workflow tool."
  check_tool "tilt" "tilt version" "Local Kubernetes development workflow."

  check_print_section "Networking, Ingress and Service Mesh"

  check_tool "cilium" "cilium version --client" "Cilium CLI."
  check_tool "hubble" "hubble version" "Cilium observability CLI."
  check_tool "istioctl" "istioctl version --remote=false" "Istio CLI."
  check_tool "linkerd" "linkerd version --client" "Linkerd CLI."

  check_print_section "Certificates, Backup and Cluster Internals"

  check_tool "cmctl" "cmctl version --client" "cert-manager CLI."
  check_tool "velero" "velero version --client-only" "Kubernetes backup and restore CLI."
  check_tool "etcdctl" "etcdctl version" "etcd administration CLI."

  check_print_section "Kubectl Plugin Manager and Plugins"

  if command -v kubectl >/dev/null 2>&1; then
    if kubectl krew version >/dev/null 2>&1; then
      echo -e "${GREEN}[OK]${NC} kubectl krew installed"
      kubectl krew version 2>/dev/null | head -n 10 || true
      CHECK_OK_COUNT=$((CHECK_OK_COUNT + 1))
    else
      echo -e "${RED}[MISSING]${NC} kubectl krew not found"
      echo "Note: Krew is the plugin manager for kubectl."
      CHECK_MISSING_COUNT=$((CHECK_MISSING_COUNT + 1))
    fi
    echo

    check_kubectl_plugin "neat" "kubectl neat --help" "Cleans Kubernetes YAML output."
    check_kubectl_plugin "tree" "kubectl tree --help" "Shows Kubernetes resource ownership tree."
    check_kubectl_plugin "who-can" "kubectl who-can --help" "RBAC permission discovery."
    check_kubectl_plugin "ctx" "kubectl ctx --help" "Context switching plugin."
    check_kubectl_plugin "ns" "kubectl ns --help" "Namespace switching plugin."
    check_kubectl_plugin "sniff" "kubectl sniff --help" "Packet capture plugin."
  else
    echo -e "${YELLOW}[WARN]${NC} kubectl not installed, skipping kubectl plugin checks."
    CHECK_WARN_COUNT=$((CHECK_WARN_COUNT + 1))
  fi

  check_print_section "Summary"

  echo -e "${GREEN}Installed:${NC} $CHECK_OK_COUNT"
  echo -e "${YELLOW}Warnings:${NC}  $CHECK_WARN_COUNT"
  echo -e "${RED}Missing:${NC}   $CHECK_MISSING_COUNT"

  echo
  echo "Recommended priority baseline:"
  echo "  kubectl helm k9s kubectx kubens stern jq yq fzf rg bat tree watch kind docker kustomize krew"
  echo
  echo "Recommended validation/security baseline:"
  echo "  kubeconform kube-score trivy sops age kubeseal"
  echo
  echo "Optional depending on stack:"
  echo "  argocd flux helmfile skaffold tilt cilium hubble istioctl linkerd cmctl velero etcdctl"
  echo
}

run_install() {
# -----------------------------------------------------------------------------
# Pre-flight
# -----------------------------------------------------------------------------

log "Pre-flight checks"

if ! command -v sudo >/dev/null 2>&1; then
  fail "sudo is required."
fi

sudo -v

if ! grep -qiE "ubuntu|debian" /etc/os-release; then
  warn "This script is optimized for Ubuntu/Debian/WSL2. Continuing anyway."
fi

mkdir -p "$TMP_DIR"
cd "$TMP_DIR"

# -----------------------------------------------------------------------------
# Base packages
# -----------------------------------------------------------------------------

log "Installing base packages with apt"

sudo apt-get update

sudo apt-get install -y \
  apt-transport-https \
  ca-certificates \
  curl \
  wget \
  git \
  gnupg \
  lsb-release \
  jq \
  fzf \
  ripgrep \
  bat \
  tree \
  procps \
  unzip \
  tar \
  gzip \
  xz-utils \
  coreutils

# Debian/Ubuntu package name compatibility: bat is often exposed as batcat.
if ! command -v bat >/dev/null 2>&1 && command -v batcat >/dev/null 2>&1; then
  log "Adding bat compatibility alias to $SHELL_RC"
  append_once "alias bat='batcat'" "$SHELL_RC"
fi

# -----------------------------------------------------------------------------
# kubectl
# -----------------------------------------------------------------------------

log "Installing kubectl"

if already_installed kubectl; then
  echo "kubectl already installed: $(kubectl version --client=true 2>/dev/null | head -n 1 || true)"
else
  sudo mkdir -p /etc/apt/keyrings
  curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.36/deb/Release.key \
    | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

  echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.36/deb/ /" \
    | sudo tee /etc/apt/sources.list.d/kubernetes.list >/dev/null

  sudo apt-get update
  sudo apt-get install -y kubectl
fi

# -----------------------------------------------------------------------------
# Helm
# -----------------------------------------------------------------------------

log "Installing helm"

if already_installed helm; then
  echo "helm already installed: $(helm version --short 2>/dev/null || true)"
else
  # Install Helm directly from the official GitHub release archive.
  # This avoids brittle GPG/repository bootstrap issues in minimal containers.
  HELM_VERSION="$(github_latest_tag helm/helm)"

  curl -fsSLO "https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz"
  tar -xzf "helm-${HELM_VERSION}-linux-amd64.tar.gz"
  sudo install -m 755 linux-amd64/helm "$INSTALL_DIR/helm"
fi

# -----------------------------------------------------------------------------
# Docker CLI / Docker engine fallback
# -----------------------------------------------------------------------------

log "Checking Docker"

if already_installed docker; then
  echo "docker already installed: $(docker version --format 'Client: {{.Client.Version}}' 2>/dev/null || docker --version)"
else
  if [ "$INSTALL_DOCKER" = "true" ]; then
    warn "Docker not found. INSTALL_DOCKER=true, installing docker.io via apt."
    sudo apt-get install -y docker.io
    sudo usermod -aG docker "$USER" || true
    warn "You may need to restart your shell/session for Docker group membership to apply."
  else
    warn "Docker not found. Skipping Docker installation because INSTALL_DOCKER=false."
    warn "On WSL2, prefer Docker Desktop with WSL integration, or rerun with: INSTALL_DOCKER=true $0"
  fi
fi

# -----------------------------------------------------------------------------
# yq - Mike Farah
# -----------------------------------------------------------------------------

log "Installing yq"

YQ_ARCH="amd64"
sudo wget -q https://github.com/mikefarah/yq/releases/latest/download/yq_linux_${YQ_ARCH} -O "$INSTALL_DIR/yq"
sudo chmod +x "$INSTALL_DIR/yq"

# -----------------------------------------------------------------------------
# kustomize
# -----------------------------------------------------------------------------

log "Installing kustomize"

KUSTOMIZE_VERSION="$(github_latest_tag kubernetes-sigs/kustomize)"
KUSTOMIZE_VERSION_CLEAN="${KUSTOMIZE_VERSION#kustomize/}"
KUSTOMIZE_VERSION_CLEAN="${KUSTOMIZE_VERSION_CLEAN#v}"

curl -fsSLO "https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize/v${KUSTOMIZE_VERSION_CLEAN}/kustomize_v${KUSTOMIZE_VERSION_CLEAN}_linux_amd64.tar.gz"
tar -xzf "kustomize_v${KUSTOMIZE_VERSION_CLEAN}_linux_amd64.tar.gz"
install_binary kustomize kustomize

# -----------------------------------------------------------------------------
# k9s
# -----------------------------------------------------------------------------

log "Installing k9s"

K9S_VERSION="$(github_latest_tag derailed/k9s)"
curl -fsSLO "https://github.com/derailed/k9s/releases/download/${K9S_VERSION}/k9s_Linux_amd64.tar.gz"
tar -xzf k9s_Linux_amd64.tar.gz k9s
install_binary k9s k9s

# -----------------------------------------------------------------------------
# stern
# -----------------------------------------------------------------------------

log "Installing stern"

STERN_VERSION="$(github_latest_tag stern/stern)"
curl -fsSLO "https://github.com/stern/stern/releases/download/${STERN_VERSION}/stern_${STERN_VERSION#v}_linux_amd64.tar.gz"
tar -xzf "stern_${STERN_VERSION#v}_linux_amd64.tar.gz" stern
install_binary stern stern

# -----------------------------------------------------------------------------
# kubectx / kubens
# -----------------------------------------------------------------------------

log "Installing kubectx and kubens"

sudo apt-get install -y kubectx

# -----------------------------------------------------------------------------
# kind
# -----------------------------------------------------------------------------

log "Installing kind"

KIND_VERSION="$(github_latest_tag kubernetes-sigs/kind)"
curl -fsSL "https://kind.sigs.k8s.io/dl/${KIND_VERSION}/kind-linux-amd64" -o kind
install_binary kind kind

# -----------------------------------------------------------------------------
# kubeconform
# -----------------------------------------------------------------------------

log "Installing kubeconform"

KUBECONFORM_VERSION="$(github_latest_tag yannh/kubeconform)"
curl -fsSLO "https://github.com/yannh/kubeconform/releases/download/${KUBECONFORM_VERSION}/kubeconform-linux-amd64.tar.gz"
tar -xzf kubeconform-linux-amd64.tar.gz kubeconform
install_binary kubeconform kubeconform

# -----------------------------------------------------------------------------
# kube-score
# -----------------------------------------------------------------------------

log "Installing kube-score"

KUBE_SCORE_VERSION="$(github_latest_tag zegl/kube-score)"
KUBE_SCORE_VERSION_CLEAN="${KUBE_SCORE_VERSION#v}"

curl -fsSLO "https://github.com/zegl/kube-score/releases/download/${KUBE_SCORE_VERSION}/kube-score_${KUBE_SCORE_VERSION_CLEAN}_linux_amd64.tar.gz"
tar -xzf "kube-score_${KUBE_SCORE_VERSION_CLEAN}_linux_amd64.tar.gz" kube-score
install_binary kube-score kube-score

# -----------------------------------------------------------------------------
# pluto
# -----------------------------------------------------------------------------

log "Installing pluto"

PLUTO_VERSION="$(github_latest_tag FairwindsOps/pluto)"
PLUTO_VERSION_CLEAN="${PLUTO_VERSION#v}"

curl -fsSLO "https://github.com/FairwindsOps/pluto/releases/download/${PLUTO_VERSION}/pluto_${PLUTO_VERSION_CLEAN}_linux_amd64.tar.gz"
tar -xzf "pluto_${PLUTO_VERSION_CLEAN}_linux_amd64.tar.gz" pluto
install_binary pluto pluto

# -----------------------------------------------------------------------------
# kubent / kube-no-trouble
# -----------------------------------------------------------------------------

log "Installing kubent"

KUBENT_VERSION="$(github_latest_tag doitintl/kube-no-trouble)"
KUBENT_VERSION_CLEAN="${KUBENT_VERSION#v}"

curl -fsSLO "https://github.com/doitintl/kube-no-trouble/releases/download/${KUBENT_VERSION}/kubent-${KUBENT_VERSION_CLEAN}-linux-amd64.tar.gz"
tar -xzf "kubent-${KUBENT_VERSION_CLEAN}-linux-amd64.tar.gz" kubent
install_binary kubent kubent

# -----------------------------------------------------------------------------
# conftest
# -----------------------------------------------------------------------------

log "Installing conftest"

CONFTEST_VERSION="$(github_latest_tag open-policy-agent/conftest)"
CONFTEST_VERSION_CLEAN="${CONFTEST_VERSION#v}"

curl -fsSLO "https://github.com/open-policy-agent/conftest/releases/download/${CONFTEST_VERSION}/conftest_${CONFTEST_VERSION_CLEAN}_Linux_x86_64.tar.gz"
tar -xzf "conftest_${CONFTEST_VERSION_CLEAN}_Linux_x86_64.tar.gz" conftest
install_binary conftest conftest

# -----------------------------------------------------------------------------
# OPA
# -----------------------------------------------------------------------------

log "Installing opa"

curl -fsSL https://openpolicyagent.org/downloads/latest/opa_linux_amd64 -o opa
install_binary opa opa

# -----------------------------------------------------------------------------
# Kyverno CLI
# -----------------------------------------------------------------------------

log "Installing kyverno CLI"

KYVERNO_VERSION="$(github_latest_tag kyverno/kyverno)"
curl -fsSLO "https://github.com/kyverno/kyverno/releases/download/${KYVERNO_VERSION}/kyverno-cli_${KYVERNO_VERSION}_linux_x86_64.tar.gz"
tar -xzf "kyverno-cli_${KYVERNO_VERSION}_linux_x86_64.tar.gz" kyverno
install_binary kyverno kyverno

# -----------------------------------------------------------------------------
# Trivy
# -----------------------------------------------------------------------------

log "Installing trivy"

if already_installed trivy; then
  echo "trivy already installed: $(trivy --version | head -n 1)"
else
  wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key \
    | gpg --dearmor \
    | sudo tee /usr/share/keyrings/trivy.gpg >/dev/null

  echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" \
    | sudo tee /etc/apt/sources.list.d/trivy.list >/dev/null

  sudo apt-get update
  sudo apt-get install -y trivy
fi

# -----------------------------------------------------------------------------
# Syft and Grype
# -----------------------------------------------------------------------------

log "Installing syft and grype"

curl -fsSL https://raw.githubusercontent.com/anchore/syft/main/install.sh \
  | sudo sh -s -- -b "$INSTALL_DIR"

curl -fsSL https://raw.githubusercontent.com/anchore/grype/main/install.sh \
  | sudo sh -s -- -b "$INSTALL_DIR"

# -----------------------------------------------------------------------------
# SOPS
# -----------------------------------------------------------------------------

log "Installing sops"

SOPS_VERSION="$(github_latest_tag getsops/sops)"
curl -fsSLO "https://github.com/getsops/sops/releases/download/${SOPS_VERSION}/sops-${SOPS_VERSION}.linux.amd64"
sudo install -m 755 "sops-${SOPS_VERSION}.linux.amd64" "$INSTALL_DIR/sops"

# -----------------------------------------------------------------------------
# age
# -----------------------------------------------------------------------------

log "Installing age"

sudo apt-get install -y age

# -----------------------------------------------------------------------------
# kubeseal
# -----------------------------------------------------------------------------

log "Installing kubeseal"

KUBESEAL_VERSION="$(github_latest_tag bitnami-labs/sealed-secrets)"
KUBESEAL_VERSION_CLEAN="${KUBESEAL_VERSION#v}"

curl -fsSLO "https://github.com/bitnami-labs/sealed-secrets/releases/download/${KUBESEAL_VERSION}/kubeseal-${KUBESEAL_VERSION_CLEAN}-linux-amd64.tar.gz"
tar -xzf "kubeseal-${KUBESEAL_VERSION_CLEAN}-linux-amd64.tar.gz" kubeseal
install_binary kubeseal kubeseal

# -----------------------------------------------------------------------------
# Krew
# -----------------------------------------------------------------------------

log "Installing kubectl krew"

if kubectl krew version >/dev/null 2>&1; then
  echo "krew already installed."
else
  (
    set -x
    cd "$(mktemp -d)"
    OS="$(uname | tr '[:upper:]' '[:lower:]')"
    ARCH="$(uname -m | sed -e 's/x86_64/amd64/' -e 's/aarch64/arm64/')"
    KREW="krew-${OS}_${ARCH}"
    curl -fsSLO "https://github.com/kubernetes-sigs/krew/releases/latest/download/${KREW}.tar.gz"
    tar zxvf "${KREW}.tar.gz"
    ./"${KREW}" install krew
  )
fi

append_once 'export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"' "$SHELL_RC"

# Make Krew plugins immediately available in the current non-interactive script
# without requiring a new terminal session.
export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"
reload_shell_rc
export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"

if ! kubectl krew version >/dev/null 2>&1; then
  fail "kubectl krew is installed but not available in PATH. Current PATH: $PATH"
fi

# -----------------------------------------------------------------------------
# Krew plugins
# -----------------------------------------------------------------------------

log "Installing kubectl krew plugins"

kubectl krew update

for plugin in neat tree who-can ctx ns sniff; do
  if kubectl krew list | awk '{print $1}' | grep -qx "$plugin"; then
    echo "kubectl $plugin already installed."
  else
    kubectl krew install "$plugin"
  fi
done

# -----------------------------------------------------------------------------
# zsh completions and aliases
# -----------------------------------------------------------------------------

log "Adding managed Kubernetes shell configuration to $SHELL_RC"

write_kube_shell_config() {
  local rc_file="$1"
  local start_marker="# >>> kube-arsenal managed block >>>"
  local end_marker="# <<< kube-arsenal managed block <<<"
  local legacy_start_marker="# >>> k8s-admin-workstation managed block >>>"
  local legacy_end_marker="# <<< k8s-admin-workstation managed block <<<"
  local tmp_file

  touch "$rc_file"

  if grep -qF "$start_marker" "$rc_file" || grep -qF "$legacy_start_marker" "$rc_file"; then
    tmp_file="$(mktemp)"
    awk \
      -v start="$start_marker" \
      -v end="$end_marker" \
      -v legacy_start="$legacy_start_marker" \
      -v legacy_end="$legacy_end_marker" '
      $0 == start || $0 == legacy_start {skip=1; next}
      $0 == end || $0 == legacy_end {skip=0; next}
      skip != 1 {print}
    ' "$rc_file" > "$tmp_file"
    mv "$tmp_file" "$rc_file"
  fi

  cat >> "$rc_file" <<'K8S_ZSHRC_BLOCK'

# >>> kube-arsenal managed block >>>
# kube cli env
export KUBE_EDITOR="code --wait"
export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"

# kubectl completion
if command -v kubectl >/dev/null 2>&1; then
  source <(kubectl completion zsh)
fi

# helm completion
if command -v helm >/dev/null 2>&1; then
  source <(helm completion zsh)
fi

# kubectx / kubens completion if installed from common locations
if [ -f /opt/kubectx/completion/kubectx.zsh ]; then
  source /opt/kubectx/completion/kubectx.zsh
fi

if [ -f /opt/kubectx/completion/kubens.zsh ]; then
  source /opt/kubectx/completion/kubens.zsh
fi

# kube core
alias k='kubectl'
alias kg='kubectl get'
alias kd='kubectl describe'
alias ka='kubectl apply -f'
alias kdel='kubectl delete'
alias ke='kubectl edit'
alias kl='kubectl logs'
alias klf='kubectl logs -f'
alias kex='kubectl exec -it'
alias kpf='kubectl port-forward'
alias kctx='kubectx'
alias kns='kubens'

# kube common resources
alias kgn='kubectl get nodes'
alias kgp='kubectl get pods'
alias kgpa='kubectl get pods -A'
alias kgs='kubectl get svc'
alias kgsa='kubectl get svc -A'
alias kgd='kubectl get deploy'
alias kgda='kubectl get deploy -A'
alias kging='kubectl get ingress'
alias kginga='kubectl get ingress -A'
alias kgcm='kubectl get configmap'
alias kgsec='kubectl get secret'
alias kgns='kubectl get ns'
alias kgev='kubectl get events --sort-by=.lastTimestamp'
alias kgeva='kubectl get events -A --sort-by=.lastTimestamp'

# kube output formatting
alias kgy='kubectl get -o yaml'
alias kgj='kubectl get -o json'
alias kgw='kubectl get -o wide'
alias kpods='kubectl get pods -o wide'
alias knodes='kubectl get nodes -o wide'

# kube troubleshooting
alias kdp='kubectl describe pod'
alias kdd='kubectl describe deploy'
alias kds='kubectl describe svc'
alias kdn='kubectl describe node'
alias kdi='kubectl describe ingress'
alias klog='kubectl logs'
alias klogf='kubectl logs -f'
alias ktopn='kubectl top nodes'
alias ktopp='kubectl top pods'
alias ktoppA='kubectl top pods -A'

# kube rollout
alias krs='kubectl rollout status'
alias krh='kubectl rollout history'
alias kru='kubectl rollout undo'
alias krr='kubectl rollout restart'

# kube namespace and context
alias kcns='kubectl config set-context --current --namespace'
alias kcurrent='kubectl config current-context'
alias kcontexts='kubectl config get-contexts'

# kube k9s
alias k9='k9s'
alias k9a='k9s -A'

# stern logs
alias sl='stern'
alias sla='stern -A'

# kube deprecation and security
alias kdeprecated-pluto='pluto detect-api-resources'
alias kdeprecated-helm='pluto detect-helm'
alias kdeprecated-files='pluto detect-files -d'
alias kdeprecated-kubent='kubent'

# kube policy testing
alias opa-eval='opa eval'
alias ctest='conftest test'
alias kyv='kyverno'

# get all resources in current namespace
function kall() {
  kubectl get all
}

# get all resources in all namespaces
function kalla() {
  kubectl get all -A
}

# watch pods in current namespace
function kwp() {
  watch -n 2 kubectl get pods -o wide
}

# watch pods in all namespaces
function kwpa() {
  watch -n 2 kubectl get pods -A -o wide
}

# quickly switch namespace
function ksetns() {
  kubectl config set-context --current --namespace="$1"
}

# show current context and namespace
function kwhere() {
  echo "Context:   $(kubectl config current-context 2>/dev/null)"
  echo "Namespace: $(kubectl config view --minify --output 'jsonpath={..namespace}' 2>/dev/null)"
}

# decode a Kubernetes secret key
function ksecret-decode() {
  local secret="$1"
  local key="$2"

  if [ -z "$secret" ] || [ -z "$key" ]; then
    echo "Usage: ksecret-decode <secret-name> <key>"
    return 1
  fi

  kubectl get secret "$secret" -o jsonpath="{.data.$key}" | base64 -d
  echo
}

# restart a deployment
function krestart() {
  local deploy="$1"

  if [ -z "$deploy" ]; then
    echo "Usage: krestart <deployment-name>"
    return 1
  fi

  kubectl rollout restart deployment "$deploy"
}

# follow logs for all pods matching a label selector
function klog-label() {
  local selector="$1"

  if [ -z "$selector" ]; then
    echo "Usage: klog-label <label-selector>"
    echo "Example: klog-label app=api"
    return 1
  fi

  kubectl logs -f -l "$selector" --all-containers=true
}

# port-forward a service quickly
function kpf-svc() {
  local svc="$1"
  local local_port="$2"
  local remote_port="$3"

  if [ -z "$svc" ] || [ -z "$local_port" ] || [ -z "$remote_port" ]; then
    echo "Usage: kpf-svc <service-name> <local-port> <remote-port>"
    return 1
  fi

  kubectl port-forward svc/"$svc" "$local_port":"$remote_port"
}

# follow logs for a workload by label selector
function kstern() {
  local selector="$1"

  if [ -z "$selector" ]; then
    echo "Usage: kstern <label-selector>"
    echo "Example: kstern app=api"
    return 1
  fi

  stern -l "$selector"
}

# follow logs across all namespaces by label selector
function ksternA() {
  local selector="$1"

  if [ -z "$selector" ]; then
    echo "Usage: ksternA <label-selector>"
    echo "Example: ksternA app=api"
    return 1
  fi

  stern -A -l "$selector"
}

# validate Kubernetes manifests
function kval() {
  local path="${1:-.}"
  kubeconform -strict -summary "$path"
}

# score Kubernetes manifests
function kscore() {
  local path="${1:-.}"
  kube-score score "$path"
}

# scan Kubernetes manifests with Trivy
function kscan-config() {
  local path="${1:-.}"
  trivy config "$path"
}

# test Kubernetes policies with Conftest
function kpolicy-test() {
  local resource="$1"

  if [ -z "$resource" ]; then
    echo "Usage: kpolicy-test <resource-file-or-directory>"
    return 1
  fi

  conftest test "$resource"
}

# test Kubernetes policies with Kyverno
function kyverno-test() {
  local policy="$1"
  local resource="$2"

  if [ -z "$policy" ] || [ -z "$resource" ]; then
    echo "Usage: kyverno-test <policy-file> <resource-file>"
    return 1
  fi

  kyverno apply "$policy" --resource "$resource"
}

# check for deprecated Kubernetes API versions and resources
function kdeprecated() {
  echo "== Pluto API resources =="
  pluto detect-api-resources || true

  echo
  echo "== kubent =="
  kubent || true
}

# debian/ubuntu compatibility: bat is usually exposed as batcat.
if ! command -v bat >/dev/null 2>&1 && command -v batcat >/dev/null 2>&1; then
  alias bat='batcat'
fi
# <<< kube-arsenal managed block <<<
K8S_ZSHRC_BLOCK
}

write_kube_shell_config "$SHELL_RC"

# Reload shell configuration once aliases, completions and PATH updates are written.
# This keeps the current script execution consistent with a fresh terminal session.
reload_shell_rc
export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"

# -----------------------------------------------------------------------------
# Final validation
# -----------------------------------------------------------------------------

log "Final version check"

echo
kubectl version --client=true || true
helm version || true
kustomize version || true
k9s version || true
stern --version || true
kubectx --help | head -n 3 || true
kubens --help | head -n 3 || true
kind version || true
docker version --format 'Client: {{.Client.Version}}' || true
jq --version || true
yq --version || true
fzf --version || true
bat --version 2>/dev/null || batcat --version 2>/dev/null || true
rg --version | head -n 1 || true
tree --version || true
watch --version || true
kubeconform -v || true
kube-score version || true
pluto version || true
kubent --version || true
conftest --version || true
opa version || true
kyverno version || true
trivy --version || true
grype version || true
syft version || true
sops --version || true
age --version || true
age-keygen --version || true
kubeseal --version || true
kubectl krew version || true
kubectl neat --help >/dev/null 2>&1 && echo "kubectl neat plugin: OK" || echo "kubectl neat plugin: CHECK FAILED"
kubectl tree --help >/dev/null 2>&1 && echo "kubectl tree plugin: OK" || echo "kubectl tree plugin: CHECK FAILED"
kubectl who-can --help >/dev/null 2>&1 && echo "kubectl who-can plugin: OK" || echo "kubectl who-can plugin: CHECK FAILED"
kubectl ctx --help >/dev/null 2>&1 && echo "kubectl ctx plugin: OK" || echo "kubectl ctx plugin: CHECK FAILED"
kubectl ns --help >/dev/null 2>&1 && echo "kubectl ns plugin: OK" || echo "kubectl ns plugin: CHECK FAILED"
kubectl sniff --help >/dev/null 2>&1 && echo "kubectl sniff plugin: OK" || echo "kubectl sniff plugin: CHECK FAILED"

echo
echo "Bootstrap completed."
echo "Reload your shell with:"
echo "  source $SHELL_RC"
echo
echo "Then run kube-arsenal check mode:"
echo "  $0 --check"

}


main() {
  case "${1:-}" in
    -i|--install)
      shift
      if [ "$#" -ne 0 ]; then
        fail "Unexpected argument(s) for install mode: $*"
      fi
      run_install
      ;;
    -c|--check)
      shift
      if [ "$#" -ne 0 ]; then
        fail "Unexpected argument(s) for check mode: $*"
      fi
      run_check
      ;;
    -h|--help)
      show_help
      ;;
    "")
      show_help
      ;;
    *)
      echo "[ERROR] Unknown option: $1" >&2
      echo >&2
      show_help >&2
      exit 1
      ;;
  esac
}

main "$@"
