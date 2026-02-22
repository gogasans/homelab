# Module: proxmox-vm

Provisions a single Ubuntu VM on a Proxmox VE node by cloning a cloud-init-ready template.
Uploads a rendered cloud-init user-data snippet and configures static networking.

## Usage

```hcl
module "my_vm" {
  source = "../../modules/proxmox-vm"

  vm_name          = "my-vm"
  proxmox_node     = "pve1"
  vm_id            = 100
  template_id      = 9000
  template_node    = "pve2"
  cores            = 2
  memory_mb        = 4096
  os_disk_gb       = 50
  data_disk_gb     = 100
  vm_disk_storage  = "local-lvm"
  snippets_storage = "local"
  network_bridge   = "vmbr0"
  ip_address       = "192.168.10.100/24"
  gateway          = "192.168.10.1"
  dns_servers      = ["192.168.10.1", "1.1.1.1"]

  cloud_init_config = templatefile("${path.module}/cloud-init/my-vm.yaml.tftpl", {
    ssh_public_key = var.ssh_public_key
  })
}
```

## Requirements

- Proxmox API token set via `PROXMOX_VE_API_TOKEN` environment variable
- Snippets content type enabled on the storage specified by `snippets_storage`
- A cloud-init-ready VM template at `template_id` on `template_node`
- `qemu-guest-agent` installed inside the VM (required for bpg provider IP readback)

## Inputs

| Name | Type | Required | Description |
|---|---|---|---|
| `vm_name` | string | yes | VM hostname and Proxmox display name |
| `description` | string | no | Optional Proxmox UI description |
| `proxmox_node` | string | yes | Proxmox node to create the VM on |
| `vm_id` | number | yes | Proxmox VM ID (unique cluster-wide) |
| `template_id` | number | yes | Source template VM ID |
| `template_node` | string | yes | Node where the template resides |
| `cores` | number | yes | vCPU count |
| `memory_mb` | number | yes | RAM in MiB |
| `os_disk_gb` | number | yes | OS disk size in GiB |
| `data_disk_gb` | number | yes | Data disk size in GiB |
| `vm_disk_storage` | string | yes | Storage pool for VM disks |
| `snippets_storage` | string | yes | Storage pool with Snippets content type |
| `network_bridge` | string | yes | Proxmox network bridge |
| `ip_address` | string | yes | Static IPv4 with CIDR (e.g. `192.168.10.120/24`) |
| `gateway` | string | yes | Default gateway |
| `dns_servers` | list(string) | yes | DNS server addresses |
| `cloud_init_config` | string | yes | Rendered cloud-init user-data YAML |

## Outputs

| Name | Description |
|---|---|
| `vm_id` | Proxmox VM ID |
| `ipv4_address` | Static IPv4 address (CIDR stripped) |
