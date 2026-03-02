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
task vault-status
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
task vault-status
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

Before deploying cert-manager (Phase 4), put the Cloudflare API token into Vault.

Add your Cloudflare API token to `.env`:
```
VAULT_ROOT_TOKEN=<root-token-from-init-output>
CLOUDFLARE_API_TOKEN=<your-cloudflare-api-token>
```

Then run:
```bash
task vault-seed-secrets
```

The task handles port-forwarding, authentication, and cleanup automatically.

Verify the write succeeded:
```bash
task vault-exec -- kv get secret/cert-manager
```

**Document this path:** `secret/cert-manager.cloudflare_api_token` is used by
the `ExternalSecret` at `kubernetes/infrastructure/configs/cert-manager/cloudflare-token-external-secret.yaml`.

---

## Step 5: Create the cluster-vars ConfigMap

The `infra-configs` Flux Kustomization uses post-build variable substitution to inject
`${ACME_EMAIL}` and `${DOMAIN}` into cert-manager ClusterIssuers at reconcile time.
These values are not committed to git — they live only in the cluster as a ConfigMap.

Add your values to `.env`:
```
ACME_EMAIL=you@example.com
DOMAIN=yourdomain.com
```

Then run:
```bash
task configure-cluster-vars
```

This creates (or updates) the `cluster-vars` ConfigMap in `flux-system`. Flux will pick
it up within 10 minutes (or sooner if reconciliation is triggered by a push).

**This step is required before `infra-configs` can reconcile.** Without it, Flux will
fail with: `post build failed: substitute from 'ConfigMap/cluster-vars' error: configmaps "cluster-vars" not found`.

---

## Step 6: Verify External Secrets Operator can reach Vault

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

Vault is now initialized, unsealed, and configured. The cluster-vars ConfigMap is in place.
Flux will reconcile `infra-configs` and apply the ClusterSecretStore, ExternalSecret, and
ClusterIssuers. Continue with Phase 4 (Traefik + wildcard TLS).

**Reminder:** Vault seals itself on every pod restart. See `docs/runbooks/vault-unseal.md`
for the day-to-day unseal procedure.
