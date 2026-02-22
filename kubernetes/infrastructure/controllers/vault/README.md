# Vault

HashiCorp Vault deployed via FluxCD HelmRelease.

**Why:** See [ADR 004](../../../../docs/adr/004-vault-secrets-management.md).

## Configuration highlights

- **Backend:** Raft integrated storage (no external database)
- **Replicas:** 1 (single replica; HA requires 3+ for Raft quorum — future work)
- **Auto-unseal:** Not configured (manual unseal required after pod restart — see ADR 004)
- **Agent injector:** Disabled (using External Secrets Operator instead)
- **UI:** Enabled, exposed via Traefik IngressRoute (see `kubernetes/infrastructure/configs/vault/`)

## After deployment

Vault starts in a **sealed** state. Before it can serve any requests, it must be initialized
and unsealed. This is a one-time manual operation.

Follow **[docs/runbooks/vault-init.md](../../../../docs/runbooks/vault-init.md)** completely
before proceeding to any other phase.

## Day-to-day operations

```bash
make vault-status   # check seal status
make vault-unseal   # unseal after pod restart
```

## Upgrading

1. Check the [Vault Helm chart changelog](https://github.com/hashicorp/vault-helm/blob/main/CHANGELOG.md)
2. Check the [Vault release notes](https://developer.hashicorp.com/vault/docs/release-notes) for breaking changes
3. Update `version` in `helmrelease.yaml` and `tag` in `values.yaml`
4. Open a PR — Flux will apply the upgrade on merge
5. Monitor Vault logs during the upgrade: `kubectl logs -n vault vault-0 -f`
