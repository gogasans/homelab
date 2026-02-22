output "vm_id" {
  description = "The VM ID assigned in Proxmox."
  value       = proxmox_virtual_environment_vm.vm.vm_id
}

output "ipv4_address" {
  description = "The static IPv4 address of the VM (CIDR stripped)."
  value       = split("/", var.ip_address)[0]
}
