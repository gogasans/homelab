#!/usr/bin/env bash
# bootstrap.sh
# Orchestrates the Phase 3 FluxCD bootstrap sequence.
# Run this AFTER:
#   - Phase 1 (OpenTofu): VMs are created and reachable
#   - Phase 2 (Ansible): k3s is installed and the cluster is healthy
#
# Prerequisites:
#   - GITHUB_TOKEN env var with repo read/write permissions
#   - GITHUB_OWNER env var set to your GitHub username
#   - kubeconfig placed at <repo-root>/.kube/config (or KUBECONFIG set to override)
#   - flux CLI installed (version from .tool-versions)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

GITHUB_OWNER="${GITHUB_OWNER:-}"        # Your GitHub username
GITHUB_REPO="${GITHUB_REPO:-homelab}"  # Repository name
CLUSTER_PATH="kubernetes/clusters/homelab"

# ── Validation ─────────────────────────────────────────────────────────────

echo "==> Validating prerequisites..."

MISSING=0

if [ -z "${GITHUB_TOKEN:-}" ]; then
  echo "Error: GITHUB_TOKEN is not set."
  MISSING=1
fi

if [ -z "${GITHUB_OWNER:-}" ]; then
  echo "Error: GITHUB_OWNER is not set. Set it to your GitHub username."
  echo "  export GITHUB_OWNER=<your-github-username>"
  MISSING=1
fi

KUBECONFIG="${KUBECONFIG:-$ROOT_DIR/.kube/config}"
export KUBECONFIG

if [ ! -f "$KUBECONFIG" ]; then
  # Try to get the CP IP from tofu output to make the instructions actionable
  CP_IP=""
  if command -v tofu &>/dev/null; then
    CP_IP=$(tofu -chdir="$ROOT_DIR/tofu/environments/homelab" output -raw control_plane_ip 2>/dev/null || true)
  fi

  echo "Error: kubeconfig not found at $KUBECONFIG"
  echo "  Copy your homelab kubeconfig there:"
  if [ -n "$CP_IP" ]; then
    echo "  scp ubuntu@${CP_IP}:/home/ubuntu/.kube/config $ROOT_DIR/.kube/config"
    echo "  Then update the server address:"
    echo "  sed -i '' 's|https://127.0.0.1:6443|https://${CP_IP}:6443|' $ROOT_DIR/.kube/config"
  else
    echo "  scp or manually copy k3s kubeconfig file to <repo-root>/.kube/config and then update the server address to the node IP"
    echo "  (Tip: run 'tofu -chdir=tofu/environments/homelab output control_plane_ip' to get the IP)"
  fi
  MISSING=1
fi

if [ $MISSING -eq 1 ]; then
  exit 1
fi

# Check cluster is reachable
if ! kubectl cluster-info &>/dev/null; then
  echo "Error: cannot reach the Kubernetes cluster. Check your KUBECONFIG."
  exit 1
fi

echo "  OK: cluster is reachable"
echo ""

# ── Bootstrap FluxCD ───────────────────────────────────────────────────────

echo "==> Bootstrapping FluxCD..."
echo "  Repository: github.com/$GITHUB_OWNER/$GITHUB_REPO"
echo "  Path: $CLUSTER_PATH"
echo ""

flux bootstrap github \
  --owner="$GITHUB_OWNER" \
  --repository="$GITHUB_REPO" \
  --branch=main \
  --path="$CLUSTER_PATH" \
  --personal \
  --token-auth

echo ""
echo "==> FluxCD bootstrap complete."
echo ""
echo "==> Waiting for Flux to reconcile (this may take a few minutes)..."
flux reconcile source git flux-system

echo ""
echo "==> Flux status:"
flux get all -A

echo ""
echo "Bootstrap complete. From this point forward, changes are deployed by pushing to git."
echo "Run 'task flux-status' to check reconciliation state at any time."
