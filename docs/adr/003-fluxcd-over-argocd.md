# ADR 003 — GitOps with FluxCD over ArgoCD

**Status:** Accepted
**Date:** 2026-02-21
**Phase:** 0 (Repository bootstrap)

---

## Context

GitOps means the git repository is the source of truth for what runs in the cluster.
A GitOps operator watches the repository and automatically reconciles the cluster state
to match. The two dominant options in the Kubernetes ecosystem are FluxCD and ArgoCD.

---

## Decision

Use **FluxCD v2**.

---

## Rationale

### Resource consumption

ArgoCD requires an application server, a repository server, a Redis instance, and Dex
for SSO — in addition to the core controllers. On a 2-node homelab where the control
plane VM has 8 GB RAM, this overhead is meaningful. FluxCD's controllers are lightweight
by comparison: each controller is a separate focused process (source-controller,
kustomize-controller, helm-controller, notification-controller).

### Native SOPS decryption

FluxCD's kustomize-controller has built-in support for SOPS decryption. You configure
a secret containing the age private key, reference it in the `Kustomization` spec, and
Flux decrypts `*.sops.yaml` files at reconcile time. No plugins, no additional setup.
ArgoCD requires a separate plugin or an external secrets operator to achieve the same result.

### CLI-first, git-native workflow

FluxCD is designed around `kubectl` and the `flux` CLI. There is no UI server. This is
a deliberate design choice: it forces understanding of the underlying Kubernetes objects
(HelmRelease, GitRepository, Kustomization, etc.) rather than relying on a GUI.

For someone learning platform engineering, this is the right constraint. The mental model
built with FluxCD — "everything is a Kubernetes resource, controllers reconcile toward
desired state" — transfers directly to real-world platform work.

ArgoCD's UI is a selling point for teams, but for a solo learning project, it adds
cognitive overhead without proportional benefit.

### Monorepo support

FluxCD's recommended pattern for a single cluster is a monorepo with a structured path
layout, which is what this project uses. The official `flux2-kustomize-helm-example`
reference repository directly maps to our `kubernetes/` directory structure.

---

## Consequences

**Gained:**
- Low memory footprint.
- Native SOPS decryption without extra tooling.
- Teaches git-native GitOps concepts without a GUI abstraction layer.
- Kustomization-based ordering with `dependsOn` enables explicit reconciliation control.

**Given up:**
- No built-in web UI. We compensate with the official FluxCD Grafana dashboard
  (imported in Phase 5), which gives visibility into reconciliation state.
- ArgoCD's multi-cluster management UI would be useful if we expand to multiple clusters.
  FluxCD can manage multiple clusters but requires more manual CLI work for that use case.

**Future decisions constrained:**
- Flux Notification API is used for alerting on reconciliation failures. We must configure
  at least one `Provider` and `Alert` resource as part of Phase 3 (see flux-conventions.md).

---

## References

- [FluxCD documentation](https://fluxcd.io/flux/)
- [flux2-kustomize-helm-example](https://github.com/fluxcd/flux2-kustomize-helm-example)
- [Flux vs Argo comparison](https://fluxcd.io/blog/2022/08/why-flux-vs-argocd/)
