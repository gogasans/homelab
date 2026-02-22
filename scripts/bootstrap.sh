#!/usr/bin/env bash
# bootstrap.sh
# Orchestrates the Phase 3 FluxCD bootstrap sequence.
# Run this AFTER:
#   - Phase 1 (OpenTofu): VMs are created and reachable
#   - Phase 2 (Ansible): k3s is installed and the cluster is healthy
#
# Prerequisites:
#   - GITHUB_TOKEN env var with repo read/write permissions
#   - KUBECONFIG env var pointing to the k3s cluster kubeconfig
#   - The age private key (age.key) present in the current directory or HOME
#   - flux CLI installed (version from .tool-versions)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

GITHUB_OWNER="${GITHUB_OWNER:-}"        # Your GitHub username
GITHUB_REPO="${GITHUB_REPO:-homelab}"  # Repository name
CLUSTER_PATH="kubernetes/clusters/homelab"
AGE_KEY_FILE="${AGE_KEY_FILE:-$HOME/age.key}"

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

if [ -z "${KUBECONFIG:-}" ] && [ ! -f "$HOME/.kube/config" ]; then
  echo "Error: No kubeconfig found. Set KUBECONFIG or place config at ~/.kube/config."
  MISSING=1
fi

if [ ! -f "$AGE_KEY_FILE" ]; then
  echo "Error: age private key not found at $AGE_KEY_FILE."
  echo "Set AGE_KEY_FILE to the path of your age private key."
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

# ── Step 1: Create the SOPS age secret ────────────────────────────────────

echo "==> Creating sops-age Secret in flux-system namespace..."
kubectl create namespace flux-system --dry-run=client -o yaml | kubectl apply -f -

cat "$AGE_KEY_FILE" | kubectl create secret generic sops-age \
  --namespace=flux-system \
  --from-file=age.agekey=/dev/stdin \
  --dry-run=client -o yaml | kubectl apply -f -

echo "  OK: sops-age Secret created"
echo ""

# ── Step 2: Bootstrap FluxCD ───────────────────────────────────────────────

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
echo "Run 'make flux-status' to check reconciliation state at any time."
