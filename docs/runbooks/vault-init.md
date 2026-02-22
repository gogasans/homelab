# Runbook: Vault Initialization

This is a one-time procedure performed after Vault is first deployed to the cluster.
It must be completed before any other Phase 4+ work can proceed.

**Time required:** ~20 minutes
**Risk level:** HIGH — the output of `vault operator init` must be saved immediately.
Losing the unseal keys means permanent, irrecoverable loss of all secrets in Vault.

---

## Prerequisites

- Phase 3a complete: FluxCD is running and managing the cluster
- Phase 3b complete: Vault pod is `Running` (but `Sealed: true`)
- `vault` CLI installed (version in `.tool-versions`)
- `kubectl` pointing to the homelab cluster

Verify Vault pod is running but sealed:
```bash
make vault-status
# Expected output includes: Sealed: true, Initialized: false
```

---

## Step 1: Run vault-init.sh

The script automates the full initialization and configuration sequence.

```bash
scripts/vault-init.sh
```

The script will:
1. Initialize Vault (generates 5 unseal keys + 1 root token)
2. Write the init output to `/tmp/vault-init.json`
3. **Pause and wait for you to save the file** before proceeding
4. Unseal Vault using 3 of the 5 keys
5. Enable the KV v2 secrets engine at `secret/`
6. Enable and configure the Kubernetes auth method
7. Write the `external-secrets-read` policy
8. Create the ESO Vault role
9. Delete `/tmp/vault-init.json` from disk

---

## Step 2: Save the init output (CRITICAL)

When the script pauses after initialization, open a second terminal and:

```bash
cat /tmp/vault-init.json
```

Copy the entire JSON output into your password manager. Save it as an entry like
"Vault Init — homelab" with the full JSON content. The JSON contains:

```json
{
  "unseal_keys_b64": ["key1", "key2", "key3", "key4", "key5"],
  "unseal_keys_hex": ["..."],
  "unseal_shares": 5,
  "unseal_threshold": 3,
  "recovery_keys_b64": [],
  "root_token": "hvs.xxxxxxxxxxxxxxxxxxxxxxxx"
}
```

Verify you have saved it, then press ENTER in the script window to continue.

**Important:** The `root_token` is highly privileged. Use it only for initial setup.
For ongoing operations, create a less-privileged token. Treat the root token like
a break-glass credential — store it separately from the unseal keys if possible.

---

## Step 3: Verify Vault is unsealed and configured

After the script completes:

```bash
# Check seal status
make vault-status
# Expected: Sealed: false

# Verify the secrets engine is enabled
vault secrets list
# Expected: secret/ appears as kv

# Verify the Kubernetes auth method is enabled
vault auth list
# Expected: kubernetes/ appears

# Verify the policy exists
vault policy read external-secrets-read

# Verify the ESO role exists
vault read auth/kubernetes/role/external-secrets
```

---

## Step 4: Populate secrets needed by Phase 4

Before deploying cert-manager (Phase 4), put the Cloudflare API token into Vault:

```bash
# Export the root token temporarily
export VAULT_ADDR="http://127.0.0.1:8200"
export VAULT_TOKEN="<root-token-from-init-output>"

# Port-forward Vault
kubectl port-forward -n vault svc/vault 8200:8200 &

# Put the Cloudflare API token
vault kv put secret/cert-manager cloudflare_api_token="<your-cloudflare-api-token>"

# Verify
vault kv get secret/cert-manager
```

**Document this path:** `secret/cert-manager.cloudflare_api_token` is used by
the `ExternalSecret` at `kubernetes/infrastructure/configs/cert-manager/cloudflare-token-external-secret.yaml`.

---

## Step 5: Verify External Secrets Operator can reach Vault

After ESO is deployed (Phase 3d), verify the `ClusterSecretStore` is healthy:

```bash
kubectl get clustersecretstore
# NAME            AGE   STATUS   CAPABILITIES   READY
# vault-backend   1m    Valid    ReadWrite      True
```

If the status is not `Valid`, check ESO controller logs:
```bash
kubectl logs -n external-secrets deployment/external-secrets -f
```

Common issue: The Kubernetes auth method was not configured before ESO tried to authenticate.
Wait for ESO to retry or restart the ESO pod to force an immediate retry.

---

## Vault Paths Catalog

All Vault paths used by this cluster are documented here for disaster recovery purposes.
**Update this table whenever a new secret is added to Vault.**

| Path | Key(s) | Used By | Added |
|------|--------|---------|-------|
| `secret/cert-manager` | `cloudflare_api_token` | cert-manager DNS-01 challenge | Phase 4 |

---

## After this runbook

Vault is now initialized, unsealed, and configured. Continue with Phase 3d (deploy ESO)
and then Phase 4 (core infrastructure controllers).

**Reminder:** Vault seals itself on every pod restart. See `docs/runbooks/vault-unseal.md`
for the day-to-day unseal procedure.
