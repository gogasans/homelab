# ADR 009 — Single control plane (known HA limitation)

**Status:** Accepted
**Date:** 2026-02-28
**Phase:** 2 (k3s installation)

---

## Context

A Kubernetes cluster with high availability (HA) requires at least three control plane
nodes to maintain etcd quorum. If the only control plane node goes down, the API server
becomes unreachable and the cluster cannot schedule new workloads or process changes —
though running workloads on healthy worker nodes continue until they need API interaction.

This homelab has two Proxmox hosts. The current plan allocates one VM per host:
- `k3s-cp-01` on `pve1` — control plane
- `k3s-worker-01` on `pve2` — worker

A third Proxmox host does not yet exist.

---

## Decision

Deploy a **single control plane node** (`k3s-cp-01`) with `--cluster-init` for embedded
etcd. Accept the HA limitation explicitly. Document it here rather than silently
operating a non-HA cluster.

---

## Rationale

**A two-node CP is worse than one.**
Running two control plane nodes with embedded etcd would require an external etcd cluster
or a split-brain situation. With two etcd members, quorum requires both to be up — this
offers strictly worse availability than a single node (one failure takes down etcd either
way, and split-brain is now possible). The minimum viable HA count is three.

**Hardware constraint is the real blocker.**
HA etcd needs three nodes to tolerate one failure. Acquiring a third Proxmox host and VM
is the correct fix. It is not a code problem.

**Homelab availability requirements are low.**
Downtime during a control plane failure is acceptable in this context. No SLA exists.
Running workloads on the worker continue serving until they need API interaction. Most
self-hosted applications tolerate brief API unavailability.

**`--cluster-init` preserves the upgrade path.**
Provisioning k3s with `--cluster-init` embeds etcd from the start. When a third Proxmox
host is available, adding a second and third control plane node is a matter of joining
them with `--server https://k3s-cp-01:6443`. No cluster rebuild required.

---

## Consequences

**Accepted risk:**
- If `pve1` or `k3s-cp-01` fails, the Kubernetes API server is unreachable.
- New pods cannot be scheduled until the control plane recovers.
- Running pods on the worker continue until they need API interaction (e.g., secret
  rotation, config map updates, service discovery changes).
- FluxCD reconciliation halts until the API server is restored.

**Mitigation:**
- k3s restarts automatically via systemd on crash.
- The control plane VM can be recreated from the OpenTofu module and cloud-init template
  in under 10 minutes. The etcd data directory (`/var/lib/rancher/k3s/`) is on a
  persistent disk. Cluster state survives VM-level recovery if the disk is intact.
- Full disaster recovery procedure: see `docs/runbooks/disaster-recovery.md`.

**Future work:**
- When a third Proxmox host is available, add two more control plane VMs to reach three
  total. Join them with the k3s `--server` flag. Update the OpenTofu module to support
  a `control_plane` count variable.
- Consider adding a fourth host as a second worker at the same time to maintain workload
  capacity during CP drain.

---

## References

- [k3s HA with embedded etcd](https://docs.k3s.io/datastore/ha-embedded)
- [etcd FAQ — minimum cluster size](https://etcd.io/docs/v3.5/faq/#what-is-failure-tolerance)
- ADR 001 — Use k3s as Kubernetes distribution
