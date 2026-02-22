# ADR 004 — Secrets management with HashiCorp Vault + External Secrets Operator

**Status:** Accepted
**Date:** 2026-02-21
**Phase:** 0 (Repository bootstrap) / Phase 3 (Implementation)
**Supersedes:** Initial consideration of SOPS + age

---

## Context

The global security baseline (`security-baseline.md`) requires Vault for all secrets unless
not feasible. Any GitOps-managed cluster will need secrets: database passwords, API tokens,
TLS private keys, and more. The question is how those secrets reach running pods without
ever being stored in git.

Alternatives evaluated:

| Approach | Secrets in git? | External dependency | Cluster-portable? |
|---|---|---|---|
| **Vault + ESO** | No | Vault pod in-cluster | Yes (Vault data on PV) |
| SOPS + age | Yes (encrypted) | None (age keypair) | Yes (age key in password manager) |
| Sealed Secrets | Yes (encrypted) | None (controller keypair) | No (tied to cluster keypair) |
| Manual / kubectl apply | No | None | Yes (but no auditability) |

---

## Decision

Deploy **HashiCorp Vault** (in-cluster, Raft backend) as the secrets store, with
**External Secrets Operator (ESO)** as the bridge to Kubernetes workloads.

This satisfies the security-baseline requirement and provides the most complete,
enterprise-representative secrets management pattern available for a homelab.

---

## Architecture

```
Developer (CLI)
    │
    │ vault kv put secret/app db_password=xxx
    ▼
HashiCorp Vault (k8s pod, Raft storage)
    │
    │ ESO ClusterSecretStore polls Vault
    ▼
External Secrets Operator (k8s pod)
    │
    │ creates/updates Kubernetes Secret from ExternalSecret CRD
    ▼
Kubernetes Secret (in-cluster, never in git)
    │
    │ referenced by Deployment as usual
    ▼
Application Pod
```

The `ExternalSecret` manifest (which only contains path references, not values) is
committed to git. The actual `Secret` object is created at runtime by ESO.

---

## Rationale

### Why Vault over SOPS + age

The security baseline explicitly requires Vault. Beyond compliance:

- **No secrets ever touch git.** With SOPS, encrypted values live in the repository.
  Even encrypted, this increases the attack surface — a cryptographic weakness or key
  compromise exposes historical secrets. With Vault, secret values only exist inside
  Vault's encrypted storage.
- **Audit log.** Every secret read is logged in Vault with the requestor's identity.
  With SOPS, there is no record of who decrypted what, or when.
- **Short-lived credentials.** Vault can generate dynamic secrets (e.g., database
  credentials that expire after 1 hour). SOPS stores static secrets only.
- **Fine-grained access control.** Vault policies control which pod can read which path.
  With SOPS, anyone with the age private key can read every secret.
- **Revocation.** A compromised secret can be revoked in Vault without rotating every
  other secret. With SOPS, you would need to re-encrypt all secrets with a new key.

### Why Vault over Sealed Secrets

Sealed Secrets encrypts against a cluster-specific keypair held by the controller.
If the cluster is destroyed, the controller keypair is lost and all secrets are permanently
unreadable (unless you took a backup of the controller's private key). Vault stores data
on a persistent volume that is independent of the cluster — rebuilding the cluster does not
affect Vault's data.

### Why in-cluster Vault over cloud-hosted secrets

Using AWS Secrets Manager, GCP Secret Manager, or Azure Key Vault would introduce a
cloud dependency and cost. The goal is a fully self-hosted homelab. Running Vault in-cluster
keeps everything on local hardware. Future work: add cloud KMS for auto-unseal.

### Why ESO as the bridge

ESO is the de-facto standard Kubernetes operator for syncing external secrets into Kubernetes
`Secret` objects. It supports Vault as a backend and uses Vault's Kubernetes auth method,
meaning ESO's pod authenticates via its ServiceAccount token — no static credentials anywhere.

The alternative (Vault Agent Sidecar Injector) injects secrets as files into each pod via a
sidecar. This works but is more complex to configure per-deployment and does not create
standard Kubernetes Secrets that existing charts expect. ESO's approach (creating Kubernetes
Secrets from `ExternalSecret` CRDs) is more compatible with off-the-shelf Helm charts.

---

## Consequences

**Gained:**
- Secrets never in git. Zero.
- Full audit trail of secret access.
- Foundation for dynamic secrets and lease-based rotation in the future.
- Kubernetes auth method means no static Vault credentials in manifests.

**Given up:**
- **Simplicity.** Vault is a stateful service with an operational lifecycle: initialize,
  unseal after restarts, back up, and recover. SOPS + age has none of this overhead.
- **Bootstrap complexity.** Vault must be running before any secret-dependent service
  can start. If Vault crashes after a node restart, the entire cluster is degraded until
  an operator manually unseals it.
- **No auto-unseal initially.** Vault starts sealed after every pod restart and requires
  manual intervention. This is the most significant operational burden of this choice.
  See the known limitation below.

**Known limitation — manual unseal:**

Vault seals itself on startup for security. Auto-unseal requires an external KMS (AWS KMS,
GCP Cloud KMS, etc.) which introduces a cloud dependency. For now, unseal is manual:
`make vault-unseal`. This means after any Vault pod restart, someone must manually unseal
before apps that depend on secrets will start.

**Mitigation:** Document clearly. Set up monitoring/alerting on Vault seal status.
**Future work:** Integrate a cloud KMS for auto-unseal (even a free-tier AWS KMS key costs
~$1/month and would eliminate the manual step entirely).

**Operational rules:**
- Vault root token and unseal keys live in your password manager only.
- All Vault secret paths are documented in `docs/runbooks/vault-init.md` for disaster recovery.
- Vault policy HCL files are committed to git in `kubernetes/infrastructure/configs/vault/policies/`.
  (Policies are configuration, not secrets — they are safe to commit.)
- Every component has its own Vault policy following least-privilege.

---

## References

- [HashiCorp Vault documentation](https://developer.hashicorp.com/vault/docs)
- [Vault Helm chart](https://github.com/hashicorp/vault-helm)
- [External Secrets Operator](https://external-secrets.io/)
- [ESO Vault provider docs](https://external-secrets.io/latest/provider/hashicorp-vault/)
- [Vault Kubernetes auth method](https://developer.hashicorp.com/vault/docs/auth/kubernetes)
- [KV Secrets Engine v2](https://developer.hashicorp.com/vault/docs/secrets/kv/kv-v2)
