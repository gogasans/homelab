# Architecture Decision Records

This directory contains Architecture Decision Records (ADRs) for the homelab project.

ADRs capture significant technology choices, including the context that led to the decision,
the options considered, what was chosen, and the trade-offs accepted. They are written
*before* implementation begins, which forces clear thinking and creates an honest record
even when the decision later turns out to be wrong.

Format: [Michael Nygard's ADR format](https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions)

## Index

| ADR | Title | Status | Phase |
|-----|-------|--------|-------|
| [001](001-use-k3s.md) | Use k3s as Kubernetes distribution | Accepted | 0 |
| [002](002-opentofu-bpg-provider.md) | Use OpenTofu with bpg/proxmox provider | Accepted | 0 |
| [003](003-fluxcd-over-argocd.md) | GitOps with FluxCD over ArgoCD | Accepted | 0 |
| [004](004-vault-secrets-management.md) | Secrets management with HashiCorp Vault + ESO | Accepted | 0 |
| [005](005-traefik-v3-ingress.md) | Traefik v3 as ingress controller | Accepted | 4 |
| [006](006-cert-manager-dns01.md) | cert-manager with DNS-01 for wildcard TLS | Accepted | 4 |
| [007](007-storage-local-path-to-longhorn.md) | Storage: local-path-provisioner → Longhorn | Accepted | 6 |
| [008](008-observability-stack.md) | Observability: kube-prometheus-stack + Loki + Alloy | Accepted | 5 |
| [009](009-single-cp-not-ha.md) | Single control plane (known HA limitation) | Accepted | 2 |
| [010](010-github-actions-ci.md) | GitHub Actions for CI with hosted runners | Accepted | 0 |
| [011](011-monorepo-structure.md) | Monorepo structure for all infrastructure | Accepted | 0 |
| [012](012-alloy-over-promtail.md) | Grafana Alloy over Promtail for log collection | Accepted | 5 |

## ADR Statuses

- **Proposed** — under consideration, not yet implemented
- **Accepted** — implemented or approved for implementation
- **Deprecated** — superseded by a later decision
- **Superseded by [XXX]** — replaced by a specific later ADR
