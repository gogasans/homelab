#!/usr/bin/env bash
# vault-unseal.sh
# Unseals Vault after a pod restart. Prompts for 3 unseal keys interactively.
# Run this whenever Vault starts in a sealed state.
#
# When to run: after any Vault pod restart (node reboot, pod eviction, upgrade).
# How to know Vault is sealed: `make vault-status` shows "Sealed: true".
#
# The unseal keys are in your password manager (saved during vault-init.sh).

set -euo pipefail

VAULT_NAMESPACE="vault"
VAULT_POD="vault-0"
VAULT_PORT="8200"
VAULT_ADDR="http://127.0.0.1:${VAULT_PORT}"

export VAULT_ADDR

# ── Check if already unsealed ────────────────────────────────────────────────

echo "==> Checking Vault seal status..."

VAULT_STATUS=$(kubectl exec -n "$VAULT_NAMESPACE" "$VAULT_POD" -- vault status -format=json 2>/dev/null || echo '{}')

if echo "$VAULT_STATUS" | grep -q '"sealed":false'; then
  echo "Vault is already unsealed. Nothing to do."
  kubectl exec -n "$VAULT_NAMESPACE" "$VAULT_POD" -- vault status
  exit 0
fi

if ! echo "$VAULT_STATUS" | grep -q '"initialized":true'; then
  echo "Error: Vault is not initialized. Run scripts/vault-init.sh first."
  exit 1
fi

echo "  Vault is sealed. Starting port-forward for unseal..."
echo ""

# ── Port-forward ─────────────────────────────────────────────────────────────

kubectl port-forward -n "$VAULT_NAMESPACE" "$VAULT_POD" "${VAULT_PORT}:${VAULT_PORT}" &
PF_PID=$!
trap "kill $PF_PID 2>/dev/null; exit" INT TERM EXIT

sleep 3

# ── Unseal ───────────────────────────────────────────────────────────────────

echo "Enter 3 unseal keys (from your password manager)."
echo "Keys are not echoed to the terminal."
echo ""

for i in 1 2 3; do
  echo -n "Unseal key $i/3: "
  read -r -s UNSEAL_KEY
  echo ""
  vault operator unseal "$UNSEAL_KEY"
done

echo ""
echo "==> Vault unseal complete. Verifying status..."
vault status

echo ""
echo "Vault is unsealed. ESO will resume syncing ExternalSecrets shortly."
echo "Check ESO status: kubectl get externalsecrets -A"
