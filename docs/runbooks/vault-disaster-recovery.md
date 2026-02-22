# Runbook: Vault Disaster Recovery

Use this runbook when Vault's persistent volume is lost (disk failure, accidental PVC
deletion) or when the entire cluster needs to be rebuilt from scratch.

**Scenarios covered:**
1. Vault PVC lost, cluster still running
2. Full cluster rebuild (everything gone)

---

## Before a disaster: take Raft snapshots

Vault's integrated Raft storage can be snapshotted and restored. **This must be done
proactively** — you cannot restore from a snapshot you do not have.

### Take a manual snapshot

```bash
export VAULT_ADDR="http://127.0.0.1:8200"
export VAULT_TOKEN="<your-vault-token>"  # root token or a token with snapshot permissions
kubectl port-forward -n vault vault-0 8200:8200 &

vault operator raft snapshot save vault-snapshot-$(date +%Y%m%d-%H%M%S).snap
```

Store the snapshot file off-cluster (external disk, cloud storage, etc.).

### Automate snapshots (future work)

A CronJob in the cluster can take periodic Raft snapshots and upload them to Longhorn's
backup target (MinIO or S3) after Phase 6. This is documented as future work.

---

## Scenario 1: Vault PVC lost, cluster still running

Vault data is gone but the cluster (k3s, FluxCD, Longhorn) is still functioning.

**What this means:** All secrets in Vault are permanently lost. You must:
1. Redeploy Vault with a fresh PVC
2. Re-initialize Vault
3. Re-populate all secrets from your password manager

**Steps:**

```bash
# Delete the existing Vault resources to reset state
kubectl delete helmrelease -n vault vault
kubectl delete pvc -n vault vault-data-vault-0
kubectl delete pod -n vault vault-0

# Wait for Flux to reconcile Vault back to a fresh state
flux reconcile kustomization infrastructure --with-source

# Vault will start sealed and uninitialized
make vault-status

# Run vault-init.sh again (full re-initialization)
scripts/vault-init.sh
```

After re-initialization, re-populate all secrets from the Vault Paths Catalog in
`docs/runbooks/vault-init.md`. Every secret must be re-entered manually.

**If you have a Raft snapshot:**

```bash
# Initialize with 1 key share (just to get a token for the restore)
vault operator init -key-shares=1 -key-threshold=1 -format=json > /tmp/temp-init.json

# Unseal with the temporary key
vault operator unseal "$(jq -r .unseal_keys_b64[0] /tmp/temp-init.json)"
export VAULT_TOKEN="$(jq -r .root_token /tmp/temp-init.json)"

# Restore the Raft snapshot
vault operator raft snapshot restore vault-snapshot-YYYYMMDD.snap

# The snapshot restores the original unseal keys — use your original unseal keys from now on
rm /tmp/temp-init.json
```

---

## Scenario 2: Full cluster rebuild

The entire cluster is gone. You are starting from a fresh k3s installation.

**Steps:**

1. Complete Phases 1–3a (VM provisioning → k3s → FluxCD bootstrap)

2. Deploy Vault via FluxCD (Phase 3b). Vault starts sealed.

3. **Re-initialize Vault.** Your old Vault data is gone (unless you have a Raft snapshot).
   Run `scripts/vault-init.sh` for a fresh initialization.

4. **Reconfigure the Kubernetes auth method.** This is critical and easy to forget.
   The Kubernetes auth method stores the old cluster's CA cert and API server URL.
   After a full rebuild, the cluster CA cert is different (unless you restore it from backup).
   The `scripts/vault-init.sh` script reconfigures Kubernetes auth automatically.

5. **Re-populate all secrets.** Use the Vault Paths Catalog in `vault-init.md` to
   re-enter every secret into Vault.

6. **Verify ESO.** After ESO is deployed (Phase 3d), check that the ClusterSecretStore
   reaches `Valid` status: `kubectl get clustersecretstore`

---

## Vault Paths Catalog (keep this updated)

This table is the recovery reference. Every secret in Vault must be listed here.
See the full catalog in [vault-init.md](./vault-init.md).

---

## Lessons from this scenario

If Vault data loss occurs, add an entry to [docs/lessons-learned/README.md](../lessons-learned/README.md)
documenting what happened and how to prevent it (e.g., set up automated Raft snapshots).
