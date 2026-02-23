# Ansible

Configures the k3s nodes provisioned by OpenTofu. Roles are organized by concern and designed
to be idempotent — running any playbook twice produces zero changes on the second run.

## Prerequisites

- VMs deployed and reachable (see [tofu/environments/homelab/](../tofu/environments/homelab/))
- SSH agent loaded with the key authorized on the VMs
- Ansible installed: `mise install`

## Inventory

Dynamic inventory via `inventory/tofu_inventory.py`. The script reads IPs directly from
OpenTofu outputs at runtime — no hardcoded addresses in the repo.

| Host | Group |
|---|---|
| k3s-cp-01 | control_plane |
| k3s-worker-01 | workers |

IPs are sourced from `tofu output control_plane_ip` and `tofu output worker_ip`
(see [tofu/environments/homelab/outputs.tf](../tofu/environments/homelab/outputs.tf)).

**Prerequisite:** `make tofu-apply` must have completed at least once (state file must exist).

To inspect the resolved inventory:

```bash
ansible-inventory --list
```

## Usage

```bash
# Verify connectivity
ansible all -m ping

# Full site playbook (Phase 2+)
ansible-playbook playbooks/site.yaml
```

## Configuration

| Variable | File | Description |
|---|---|---|
| `ansible_user` | `group_vars/all.yaml` | SSH user on all nodes (`ubuntu`) |
| `k3s_version` | `group_vars/all.yaml` | Pinned k3s version — never `latest` |
