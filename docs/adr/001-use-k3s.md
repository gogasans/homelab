# ADR 001 — Use k3s as Kubernetes distribution

**Status:** Accepted
**Date:** 2026-02-21
**Phase:** 0 (Repository bootstrap)

---

## Context

The homelab consists of two bare metal Proxmox hosts, each running one VM. The total
available RAM across both VMs is estimated at 24 GB (8 GB control plane, 16 GB worker).
The goal is to run a real Kubernetes cluster that demonstrates production-like practices
without wasting resources on cluster management overhead.

Alternatives evaluated:

| Distribution | Description |
|---|---|
| **k3s** | Single binary, bundles containerd + CoreDNS + Flannel + local-path-provisioner |
| **k0s** | Similar to k3s, no bundled CNI, single binary |
| **RKE2** | Hardened k8s for CIS benchmarks; heavier than k3s |
| **microk8s** | Canonical snap-based distribution |
| **kubeadm** | Upstream tool; requires manual installation of every component |
| **kind** | Kubernetes in Docker; designed for development, not real clusters |

---

## Decision

Use **k3s** at a pinned version.

---

## Rationale

**k3s fits the constraint (lightweight + functional).**
A standard kubeadm cluster or RKE2 cluster requires substantially more RAM for etcd,
control plane components, and optional add-ons. k3s runs a functional cluster on as
little as 512 MB RAM on the control plane and is the most popular homelab distribution
for this reason.

**k3s bundles the right defaults.**
Out of the box: containerd, CoreDNS, Flannel (CNI), Traefik (ingress), local-path-provisioner
(storage), and klipper-lb (LoadBalancer service type). We disable Traefik and servicelb
intentionally and replace them with our own GitOps-managed versions, but having them
available as fallbacks is useful during bootstrapping.

**k3s uses embedded etcd.**
With the `--cluster-init` flag, k3s runs etcd inside the same process. When we add a
third control plane node later, we simply join it with `--server`. No external etcd
cluster to manage.

**k3s is production-grade.**
Used by SUSE, Rancher, and a large community. It is not a toy distribution. Several
real-world production deployments run k3s. The single-binary model simplifies upgrades
(pin a version, replace the binary, restart the service).

**k0s is comparable but has less community documentation.**
k0s is a valid alternative with a slightly different design philosophy (no bundled CNI).
The decision between k3s and k0s is close; k3s won on community size and tutorial
availability for learning.

**RKE2 is overkill.**
RKE2 targets CIS benchmark compliance and hardened environments. The complexity and
resource overhead are not justified for a homelab.

---

## Consequences

**Gained:**
- Low resource overhead.
- Single binary simplifies upgrades and rollbacks.
- Embedded etcd removes an external dependency.
- Large community of tutorials and examples to reference while learning.

**Given up:**
- k3s bundles components (Traefik, Flannel) that we override. The bundled versions exist
  alongside our GitOps-managed ones during bootstrap — this can cause confusion.
- Flannel is a simple CNI. If we want NetworkPolicy enforcement or advanced routing in
  the future, we will need to replace Flannel with Cilium or Calico. This is future work.

**Future decisions constrained:**
- If we need NetworkPolicy enforcement, we must migrate the CNI. This will require
  a cluster reconfiguration. Document before doing.
- Adding a third control plane node for HA requires network access to all nodes and
  attention to etcd quorum during the join. See ADR 009.

---

## References

- [k3s documentation](https://docs.k3s.io/)
- [k3s GitHub](https://github.com/k3s-io/k3s)
