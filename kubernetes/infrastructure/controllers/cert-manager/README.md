# cert-manager

Installs [cert-manager](https://cert-manager.io) v1.16.3 via Helm, managed by FluxCD.

cert-manager issues and renews TLS certificates. This homelab uses it with the DNS-01
ACME challenge and Cloudflare as the DNS provider to issue Let's Encrypt wildcard
certificates without requiring a publicly reachable port 80.

## Design decisions

- **CRDs installed via Helm** (`crds.enabled: true`) — keeps CRDs and the controller
  version in sync. Major version upgrades require extra care (see cert-manager upgrade
  documentation before bumping the chart version).
- **DNS-01 challenge** — enables wildcard certs and works without public ingress.
  The Cloudflare API token required by the ClusterIssuer is pulled from Vault by ESO
  (see `kubernetes/infrastructure/configs/cert-manager/`).
- **Staging issuer first** — always validate with `letsencrypt-staging` before switching
  to `letsencrypt-production`. Let's Encrypt production rate limits are 5 duplicate
  certs/registered domain/week.

## Dependencies

- FluxCD Kustomization `infra-controllers-external-secrets` must reconcile first
  (ESO is needed to sync the Cloudflare API token from Vault before ClusterIssuers work).
- Vault must be initialized and unsealed (see `docs/runbooks/vault-init.md`).

## Files

| File | Purpose |
|------|---------|
| `namespace.yaml` | `cert-manager` namespace |
| `helmrepository.yaml` | Jetstack Helm repository |
| `helmrelease.yaml` | cert-manager HelmRelease (chart version pinned) |
| `kustomization.yaml` | Kustomize manifest list for this component |
