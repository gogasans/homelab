# ---------------------------------------------------------------------------
# Proxmox connection
# ---------------------------------------------------------------------------

variable "proxmox_endpoint" {
  description = "Proxmox API endpoint URL, e.g. \"https://192.168.10.6:8006\"."
  type        = string
}

variable "proxmox_insecure" {
  description = "Skip TLS certificate verification. Set to true only for self-signed certs."
  type        = bool
  default     = false
}

# ---------------------------------------------------------------------------
# Storage
# ---------------------------------------------------------------------------

variable "vm_disk_storage" {
  description = "Proxmox storage pool for VM OS and data disks (must support 'images' content type)."
  type        = string
}

variable "snippets_storage" {
  description = "Proxmox storage pool for cloud-init snippet files (must have 'snippets' content type enabled)."
  type        = string
}

# ---------------------------------------------------------------------------
# Network
# ---------------------------------------------------------------------------

variable "network_bridge" {
  description = "Proxmox network bridge to attach VM NICs to."
  type        = string
}

variable "gateway" {
  description = "Default gateway for all VMs."
  type        = string
}

variable "dns_servers" {
  description = "DNS server IP addresses injected via cloud-init."
  type        = list(string)
}

# ---------------------------------------------------------------------------
# VM template
# ---------------------------------------------------------------------------

variable "template_id" {
  description = "VM ID of the Ubuntu 24.04 cloud-init template to clone."
  type        = number
}

variable "template_node" {
  description = "Proxmox node where the template was created."
  type        = string
}

# ---------------------------------------------------------------------------
# SSH
# ---------------------------------------------------------------------------

variable "ssh_public_key" {
  description = "SSH public key injected into all VMs via cloud-init. Use the matching private key for SSH and Ansible."
  type        = string
}

# ---------------------------------------------------------------------------
# Control plane VM — k3s-cp-01
# ---------------------------------------------------------------------------

variable "cp_node" {
  description = "Proxmox node to create the control plane VM on."
  type        = string
}

variable "cp_ip_address" {
  description = "Static IPv4 address with CIDR for the control plane VM, e.g. \"192.168.10.120/24\"."
  type        = string
}

variable "cp_cores" {
  description = "vCPU cores for the control plane VM."
  type        = number
}

variable "cp_memory_mb" {
  description = "RAM in MiB for the control plane VM."
  type        = number
}

variable "cp_os_disk_gb" {
  description = "OS disk size in GiB for the control plane VM."
  type        = number
}

variable "cp_data_disk_gb" {
  description = "Longhorn data disk size in GiB for the control plane VM."
  type        = number
}

# ---------------------------------------------------------------------------
# Worker VM — k3s-worker-01
# ---------------------------------------------------------------------------

variable "worker_node" {
  description = "Proxmox node to create the worker VM on."
  type        = string
}

variable "worker_ip_address" {
  description = "Static IPv4 address with CIDR for the worker VM, e.g. \"192.168.10.121/24\"."
  type        = string
}

variable "worker_cores" {
  description = "vCPU cores for the worker VM."
  type        = number
}

variable "worker_memory_mb" {
  description = "RAM in MiB for the worker VM."
  type        = number
}

variable "worker_os_disk_gb" {
  description = "OS disk size in GiB for the worker VM."
  type        = number
}

variable "worker_data_disk_gb" {
  description = "Longhorn data disk size in GiB for the worker VM."
  type        = number
}
