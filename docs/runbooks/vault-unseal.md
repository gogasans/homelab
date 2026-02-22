# Runbook: Vault Unseal

Vault seals itself every time the pod restarts. This is a deliberate security feature —
a sealed Vault cannot serve any requests, which limits exposure if the node is compromised
during a restart.

**When to run:** after any Vault pod restart (node reboot, pod eviction, Vault upgrade).
**Time required:** ~5 minutes
**Impact:** All ESO-synced secrets and any apps that depend on them are unavailable until unsealed.

---

## How to know Vault is sealed

```bash
make vault-status
```

If the output includes `Sealed: true`, Vault needs to be unsealed.

You may also notice:
- `kubectl get externalsecrets -A` shows errors like "connection refused" or "permission denied"
- Applications fail to start because their secrets cannot be synced
- ESO controller logs show connection errors to Vault

---

## Quick unseal (recommended)

```bash
make vault-unseal
```

This runs `scripts/vault-unseal.sh` which:
1. Port-forwards to the Vault pod
2. Prompts you for 3 of the 5 unseal keys interactively (input is not echoed)
3. Verifies the sealed status after each key
4. Confirms Vault is unsealed at the end

Retrieve your 3 unseal keys from your password manager before running.

---

## Manual unseal (alternative)

If the script fails, unseal manually:

```bash
# Port-forward
kubectl port-forward -n vault vault-0 8200:8200 &

export VAULT_ADDR="http://127.0.0.1:8200"

# Run 3 times with different keys
vault operator unseal
vault operator unseal
vault operator unseal

# Verify
vault status
```

---

## After unseal

ESO will automatically retry syncing `ExternalSecret` resources. Watch the status:

```bash
# Watch ExternalSecrets come back to Ready
kubectl get externalsecrets -A -w

# Check ESO logs if something looks wrong
kubectl logs -n external-secrets deployment/external-secrets --tail=50
```

Apps waiting for secrets will restart automatically once their secrets are synced.

---

## Preventing unnecessary restarts

Vault pods restart when:
- The Vault pod is evicted (OOMKilled, node pressure, etc.)
- The node hosting Vault reboots
- A Vault upgrade is applied via FluxCD
- You manually delete the pod

To minimize unplanned restarts:
- Ensure Vault has adequate memory limits (set in `values.yaml`)
- Monitor node memory pressure in Grafana
- Plan Vault upgrades during a maintenance window and unseal immediately after

---

## Future work: Auto-unseal

Manual unseal is an operational burden. The industry solution is to configure Vault's
auto-unseal feature with a cloud KMS:

- **AWS KMS:** ~$1/month; Vault unseals itself on startup using the KMS key
- **GCP Cloud KMS:** similar cost and capability
- **Transit auto-unseal:** use a second Vault instance to unseal the first (not recommended for homelab)

When auto-unseal is configured, the seal status monitoring alert should be updated to only
alert on "sealed for more than N minutes" rather than any sealed state.

See [ADR 004](../adr/004-vault-secrets-management.md) for the full discussion.
