#!/usr/bin/env bash
# vault-init.sh
# One-time Vault initialization script. Run ONCE after Vault is first deployed.
# After this script completes, run vault-unseal.sh whenever Vault restarts.
#
# What this script does:
#   1. Initializes Vault (generates unseal keys + root token)
#   2. Unseals Vault using the generated keys
#   3. Enables the KV v2 secrets engine at path 'secret/'
#   4. Enables the Kubernetes auth method
#   5. Configures the Kubernetes auth method for this cluster
#   6. Writes the external-secrets Vault policy
#   7. Creates the Vault role for ESO
#
# CRITICAL: The init output (unseal keys + root token) is written to /tmp/vault-init.json.
# YOU MUST save this file to your password manager and then delete it from disk.
# If you lose the unseal keys, Vault's data is permanently inaccessible.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

VAULT_NAMESPACE="vault"
VAULT_POD="vault-0"
VAULT_PORT="8200"
VAULT_ADDR="http://127.0.0.1:${VAULT_PORT}"
INIT_OUTPUT="/tmp/vault-init.json"

ESO_NAMESPACE="external-secrets"
ESO_SERVICE_ACCOUNT="external-secrets"
VAULT_POLICY_FILE="$ROOT_DIR/kubernetes/infrastructure/configs/vault/policies/external-secrets-read.hcl"

export VAULT_ADDR

# ── Preflight ────────────────────────────────────────────────────────────────

echo "==> Checking prerequisites..."

if ! kubectl get namespace "$VAULT_NAMESPACE" &>/dev/null; then
  echo "Error: namespace '$VAULT_NAMESPACE' not found. Is Vault deployed via Flux?"
  exit 1
fi

VAULT_STATUS=$(kubectl exec -n "$VAULT_NAMESPACE" "$VAULT_POD" -- vault status -format=json 2>/dev/null || echo '{"initialized":false}')
if echo "$VAULT_STATUS" | grep -q '"initialized":true'; then
  echo "Error: Vault is already initialized. Run vault-unseal.sh to unseal it."
  echo "If you need to re-initialize (data loss!), delete the Vault PVC and pod first."
  exit 1
fi

echo "  OK: Vault pod found and not yet initialized"
echo ""

# ── Port-forward ─────────────────────────────────────────────────────────────

echo "==> Starting port-forward to Vault..."
kubectl port-forward -n "$VAULT_NAMESPACE" "$VAULT_POD" "${VAULT_PORT}:${VAULT_PORT}" &
PF_PID=$!
trap "kill $PF_PID 2>/dev/null; exit" INT TERM EXIT

sleep 3  # Give the port-forward time to establish

# ── Initialize ───────────────────────────────────────────────────────────────

echo "==> Initializing Vault (5 key shares, threshold 3)..."
vault operator init \
  -key-shares=5 \
  -key-threshold=3 \
  -format=json > "$INIT_OUTPUT"

echo ""
echo "┌─────────────────────────────────────────────────────────────────┐"
echo "│  CRITICAL: Save the contents of $INIT_OUTPUT to your           │"
echo "│  password manager NOW, then delete the file.                    │"
echo "│                                                                 │"
echo "│  The unseal keys and root token are shown ONLY ONCE.            │"
echo "│  If lost, all Vault data is permanently inaccessible.           │"
echo "└─────────────────────────────────────────────────────────────────┘"
echo ""
echo "Press ENTER after you have saved the init output to your password manager..."
read -r

ROOT_TOKEN=$(jq -r '.root_token' "$INIT_OUTPUT")
UNSEAL_KEY_1=$(jq -r '.unseal_keys_b64[0]' "$INIT_OUTPUT")
UNSEAL_KEY_2=$(jq -r '.unseal_keys_b64[1]' "$INIT_OUTPUT")
UNSEAL_KEY_3=$(jq -r '.unseal_keys_b64[2]' "$INIT_OUTPUT")

# ── Unseal ───────────────────────────────────────────────────────────────────

echo "==> Unsealing Vault..."
vault operator unseal "$UNSEAL_KEY_1"
vault operator unseal "$UNSEAL_KEY_2"
vault operator unseal "$UNSEAL_KEY_3"
echo "  OK: Vault is unsealed"
echo ""

export VAULT_TOKEN="$ROOT_TOKEN"

# ── Secrets Engine ───────────────────────────────────────────────────────────

echo "==> Enabling KV v2 secrets engine at path 'secret/'..."
vault secrets enable -path=secret kv-v2
echo "  OK: KV v2 enabled"
echo ""

# ── Kubernetes Auth ───────────────────────────────────────────────────────────

echo "==> Enabling and configuring Kubernetes auth method..."
vault auth enable kubernetes

# Get the cluster's Kubernetes API server URL and CA cert
K8S_HOST=$(kubectl config view --raw --minify --flatten \
  -o jsonpath='{.clusters[].cluster.server}')
K8S_CA=$(kubectl config view --raw --minify --flatten \
  -o jsonpath='{.clusters[].cluster.certificate-authority-data}' | base64 -d)

vault write auth/kubernetes/config \
  kubernetes_host="$K8S_HOST" \
  kubernetes_ca_cert="$K8S_CA"
echo "  OK: Kubernetes auth configured (host: $K8S_HOST)"
echo ""

# ── Policy ───────────────────────────────────────────────────────────────────

echo "==> Writing external-secrets Vault policy..."
vault policy write external-secrets-read "$VAULT_POLICY_FILE"
echo "  OK: Policy 'external-secrets-read' written"
echo ""

# ── Vault Role for ESO ───────────────────────────────────────────────────────

echo "==> Creating Vault role for External Secrets Operator..."
# The role binds ESO's ServiceAccount to the policy.
# bound_service_account_namespaces restricts which namespace ESO can authenticate from.
vault write auth/kubernetes/role/external-secrets \
  bound_service_account_names="$ESO_SERVICE_ACCOUNT" \
  bound_service_account_namespaces="$ESO_NAMESPACE" \
  policies="external-secrets-read" \
  ttl="1h"
echo "  OK: Vault role 'external-secrets' created"
echo ""

# ── Cleanup ───────────────────────────────────────────────────────────────────

echo "==> Cleaning up init output file from disk..."
rm -f "$INIT_OUTPUT"
echo "  OK: $INIT_OUTPUT deleted"
echo ""

echo "┌─────────────────────────────────────────────────────────────────┐"
echo "│  Vault initialization complete.                                 │"
echo "│                                                                 │"
echo "│  Next steps:                                                    │"
echo "│  1. Add secrets: vault kv put secret/<component> <key>=<val>   │"
echo "│  2. Verify ESO: kubectl get clustersecretstore                  │"
echo "│  3. Continue with Phase 4 (cert-manager + Traefik)             │"
echo "│                                                                 │"
echo "│  REMEMBER: Vault seals itself on pod restart.                   │"
echo "│  Run 'task vault-unseal' after any Vault pod restart.           │"
echo "└─────────────────────────────────────────────────────────────────┘"
