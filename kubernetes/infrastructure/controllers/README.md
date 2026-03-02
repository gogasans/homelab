# Infrastructure Controllers

Helm-based platform controllers deployed by FluxCD. Each subdirectory is a
self-contained Flux Kustomization with its own `namespace.yaml`, `helmrepository.yaml`,
`helmrelease.yaml`, and `kustomization.yaml`.

## Reconciliation order

```
vault → external-secrets → cert-manager → (traefik, longhorn, monitoring)
```

`dependsOn` is configured in `kubernetes/clusters/homelab/infrastructure.yaml`.

## Controllers

| Directory | Chart | Purpose |
|-----------|-------|---------|
| `vault/` | hashicorp/vault | Secret storage — all secrets originate here |
| `external-secrets/` | external-secrets/external-secrets | Syncs secrets from Vault into Kubernetes Secrets |
| `cert-manager/` | jetstack/cert-manager | Issues and renews TLS certificates via Let's Encrypt DNS-01 |
| `traefik/` | traefik/traefik | Ingress controller and TLS termination (Phase 4) |
| `longhorn/` | longhorn/longhorn | Replicated block storage (Phase 6) |
| `monitoring/` | prometheus-community/kube-prometheus-stack + Loki + Alloy | Metrics and logs (Phase 5) |
