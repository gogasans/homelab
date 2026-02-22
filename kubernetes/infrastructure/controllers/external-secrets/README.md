# External Secrets Operator (ESO)

ESO bridges HashiCorp Vault and Kubernetes Secrets. It watches `ExternalSecret` CRD resources
and creates/updates Kubernetes `Secret` objects by pulling values from Vault.

**Why:** See [ADR 004](../../../../docs/adr/004-vault-secrets-management.md).

## How it works

1. ESO's `ClusterSecretStore` authenticates to Vault using the Kubernetes auth method
   (ESO's ServiceAccount token is validated by Vault against the cluster API).
2. When Flux reconciles an `ExternalSecret` manifest, ESO reads the referenced Vault path
   and creates a Kubernetes `Secret` in the target namespace.
3. The app references the `Secret` as usual. ESO keeps it synchronized at `refreshInterval`.

## Key resources

- `ClusterSecretStore`: defined in `kubernetes/infrastructure/configs/vault/cluster-secret-store.yaml`
- `ExternalSecret` resources: defined alongside each component that needs secrets

## Must deploy AFTER Vault

ESO must not be configured before Vault is initialized and the Kubernetes auth method is set up.
The Flux Kustomization for `external-secrets` has a `dependsOn` pointing to the `vault` Kustomization.

## Verification

After ESO is running, test with:
```bash
kubectl get clustersecretstore
# Should show: vault-backend   Valid   ...

kubectl get externalsecrets -A
# Should show all ExternalSecret resources and their sync status
```
