#!/usr/bin/env bash
# vault-unseal.sh
# Unseals Vault after a pod restart. Prompts for 3 unseal keys interactively.
# Run this whenever Vault starts in a sealed state.
#
# When to run: after any Vault pod restart (node reboot, pod eviction, upgrade).
# How to know Vault is sealed: `task vault-status` shows "Sealed: true".
#
# The unseal keys are in your password manager (saved during vault-init.sh).
#
# Implementation note: all vault commands run via `kubectl exec` — no port-forward
# needed because VAULT_ADDR is already set to localhost:8200 inside the pod.

set -euo pipefail

VAULT_NAMESPACE="vault"
VAULT_POD="vault-0"

# ── Check if already unsealed ────────────────────────────────────────────────

echo "==> Checking Vault seal status..."

# vault status exits 0 (unsealed), 1 (error), 2 (sealed).
# Temporarily disable set -e so we can capture output AND exit code separately.
# VAR=$(failing_cmd) || true is unreliable in bash 3.x (macOS default).
set +e
VAULT_STATUS=$(kubectl exec -n "$VAULT_NAMESPACE" "$VAULT_POD" \
  -- vault status -format=json 2>/dev/null)
set -e

if [[ -z "$VAULT_STATUS" ]]; then
  echo "Error: Could not get Vault status from pod ${VAULT_POD}."
  echo "  Check the pod is running: kubectl get pod -n ${VAULT_NAMESPACE}"
  exit 1
fi

if echo "$VAULT_STATUS" | grep -q '"sealed":false'; then
  echo "Vault is already unsealed. Nothing to do."
  kubectl exec -n "$VAULT_NAMESPACE" "$VAULT_POD" -- vault status
  exit 0
fi

if ! echo "$VAULT_STATUS" | grep -q '"initialized":true'; then
  echo "Error: Vault is not initialized. Run scripts/vault-init.sh first."
  exit 1
fi

# ── Unseal ───────────────────────────────────────────────────────────────────

echo "  Vault is sealed. Enter 3 unseal keys (from 1Password)."
echo "  Keys are not echoed to the terminal."
echo ""

for i in 1 2 3; do
  echo -n "Unseal key $i/3: "
  read -r -s UNSEAL_KEY
  echo ""
  kubectl exec -n "$VAULT_NAMESPACE" "$VAULT_POD" \
    -- vault operator unseal "$UNSEAL_KEY"
done

echo ""
echo "==> Vault unseal complete. Verifying status..."
kubectl exec -n "$VAULT_NAMESPACE" "$VAULT_POD" -- vault status

echo ""
echo "Vault is unsealed. ESO will resume syncing ExternalSecrets shortly."
echo "Check ESO status: kubectl get externalsecrets -A"
