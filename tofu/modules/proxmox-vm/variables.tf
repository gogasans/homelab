variable "vm_name" {
  description = "VM hostname and Proxmox display name."
  type        = string
}

variable "description" {
  description = "Optional description shown in the Proxmox UI."
  type        = string
  default     = ""
}

variable "proxmox_node" {
  description = "Proxmox cluster node to create the VM on."
  type        = string
}

variable "vm_id" {
  description = "Proxmox VM ID. Must be unique across the cluster."
  type        = number
}

variable "template_id" {
  description = "VM ID of the source cloud-init template to clone."
  type        = number
}

variable "template_node" {
  description = "Proxmox node where the template resides. Cross-node cloning is handled automatically."
  type        = string
}

variable "cores" {
  description = "Number of vCPU cores."
  type        = number
}

variable "memory_mb" {
  description = "RAM allocated to the VM in MiB."
  type        = number
}

variable "os_disk_gb" {
  description = "OS disk size in GiB (mounted at /)."
  type        = number
}

variable "data_disk_gb" {
  description = "Secondary data disk size in GiB (used by Longhorn)."
  type        = number
}

variable "vm_disk_storage" {
  description = "Proxmox storage pool for VM disks."
  type        = string
}

variable "snippets_storage" {
  description = "Proxmox storage pool that has the Snippets content type enabled."
  type        = string
}

variable "network_bridge" {
  description = "Proxmox network bridge to attach the VM's NIC to."
  type        = string
}

variable "ip_address" {
  description = "Static IPv4 address with CIDR prefix, e.g. \"192.168.10.120/24\"."
  type        = string
}

variable "gateway" {
  description = "Default gateway for the VM."
  type        = string
}

variable "dns_servers" {
  description = "List of DNS server IP addresses."
  type        = list(string)
}

variable "cloud_init_config" {
  description = "Rendered cloud-init user-data YAML to upload as a Proxmox snippet."
  type        = string
}
