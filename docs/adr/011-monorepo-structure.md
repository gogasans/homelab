# ADR 011 — Monorepo structure for all infrastructure

**Status:** Accepted
**Date:** 2026-02-21
**Phase:** 0 (Repository bootstrap)

---

## Context

Infrastructure for a homelab can be organized in different ways:
- **Monorepo:** IaC, Ansible, Kubernetes manifests, and app source code all in one repo
- **Polyrepo:** separate repos for infra, apps, k8s config, etc.
- **Hybrid:** infra in one repo, each app in its own repo

FluxCD supports all three patterns. The right choice depends on team size, maturity,
and operational complexity.

---

## Decision

Use a **monorepo** for all infrastructure, configuration, and (eventually) application
source code.

---

## Rationale

### Operational simplicity

With one repo, there is one place to look for everything. Cross-cutting changes
(e.g., "update k3s version and adjust the Helm chart that depends on a k3s behavior")
happen in one PR. There is no need to coordinate across multiple repositories.

### FluxCD monorepo support

The official FluxCD documentation's recommended pattern for a single cluster or a small
number of clusters is a monorepo with a structured path layout. The `kubernetes/` directory
structure in this repo directly follows the `flux2-kustomize-helm-example` reference
implementation.

### Learning context

For a learning project, context switching between multiple repositories adds cognitive
overhead without benefit. Seeing the full picture — from VM provisioning through Kubernetes
manifests to the deployed application — in one place makes the system easier to reason about.

### Future path to polyrepo

The folder structure is designed so that splitting into multiple repos later is straightforward:
- `tofu/` → infra repo
- `ansible/` → configuration repo
- `kubernetes/` → gitops repo
- Individual app directories → per-app repos (each with their own `base/` and `homelab/` kustomize layers)

This migration would require updating Flux's GitRepository sources to point to the new repos,
but the internal structure of each directory would not change.

---

## Consequences

**Gained:**
- Single source of truth for the entire system.
- Cross-cutting changes in one PR.
- Easier for portfolio reviewers to see the full picture.

**Given up:**
- As the number of apps grows, the repo becomes larger. This is manageable for a homelab.
- Repo-level GitHub Actions permissions apply to everything. Fine-grained access control
  per component is not possible without splitting repos. Not a concern for a solo project.

---

## References

- [Repository structure — FluxCD docs](https://fluxcd.io/flux/guides/repository-structure/)
- [flux2-kustomize-helm-example](https://github.com/fluxcd/flux2-kustomize-helm-example)
