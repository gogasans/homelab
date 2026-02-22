# OpenTofu Environment: homelab

Provisions the two k3s VMs (`k3s-cp-01` and `k3s-worker-01`) on Proxmox VE by calling the
[proxmox-vm module](../../modules/proxmox-vm/).

## Prerequisites

- Proxmox prerequisites completed (see [bootstrap-proxmox.md](../../../docs/runbooks/bootstrap-proxmox.md))
- `terraform.tfvars` created from `terraform.tfvars.example` and filled in
- API token exported as an environment variable (never stored in a file)

## Usage

```bash
# Export the Proxmox API token
export PROXMOX_VE_API_TOKEN="root@pam!opentofu=<your-token-secret>"

# Initialise providers
tofu init

# Review the execution plan
tofu plan

# Apply (creates both VMs)
tofu apply

# Show VM IPs after apply
tofu output
```

## Configuration

Copy `terraform.tfvars.example` to `terraform.tfvars` and fill in your values.
`terraform.tfvars` is gitignored and must never be committed.

Key values to set:

| Variable | Description |
|---|---|
| `proxmox_endpoint` | Proxmox API URL, e.g. `https://192.168.10.6:8006` |
| `proxmox_insecure` | `true` for self-signed certificate |
| `vm_disk_storage` | Storage pool for VM disks (run `pvesm status`) |
| `snippets_storage` | Storage pool with Snippets content type |
| `network_bridge` | Network bridge (run `ip link show \| grep vmbr`) |
| `gateway` | LAN gateway |
| `dns_servers` | DNS server list |
| `template_id` | VM ID of the Ubuntu 24.04 template (default: 9000) |
| `template_node` | Node where the template was created |
| `ssh_public_key` | Public key for SSH access and Ansible |

## Outputs

| Output | Description |
|---|---|
| `control_plane_ip` | IP of k3s-cp-01 |
| `worker_ip` | IP of k3s-worker-01 |

## State

State is stored locally at `terraform.tfstate` (gitignored). Future work: migrate to
an S3-compatible backend for remote state and locking.
