module "cp" {
  source = "../../modules/proxmox-vm"

  vm_name      = "k3s-cp-01"
  description  = "k3s control plane node"
  proxmox_node = var.cp_node
  vm_id        = 300

  template_id   = var.template_id
  template_node = var.template_node

  cores        = var.cp_cores
  memory_mb    = var.cp_memory_mb
  os_disk_gb   = var.cp_os_disk_gb
  data_disk_gb = var.cp_data_disk_gb

  vm_disk_storage  = var.vm_disk_storage
  snippets_storage = var.snippets_storage
  network_bridge   = var.network_bridge
  ip_address       = var.cp_ip_address
  gateway          = var.gateway
  dns_servers      = var.dns_servers

  cloud_init_config = templatefile("${path.module}/cloud-init/control-plane.yaml.tftpl", {
    ssh_public_key = var.ssh_public_key
  })
}

module "worker" {
  source = "../../modules/proxmox-vm"

  vm_name      = "k3s-worker-01"
  description  = "k3s worker node"
  proxmox_node = var.worker_node
  vm_id        = 301

  template_id   = var.template_id
  template_node = var.template_node

  cores        = var.worker_cores
  memory_mb    = var.worker_memory_mb
  os_disk_gb   = var.worker_os_disk_gb
  data_disk_gb = var.worker_data_disk_gb

  vm_disk_storage  = var.vm_disk_storage
  snippets_storage = var.snippets_storage
  network_bridge   = var.network_bridge
  ip_address       = var.worker_ip_address
  gateway          = var.gateway
  dns_servers      = var.dns_servers

  cloud_init_config = templatefile("${path.module}/cloud-init/worker.yaml.tftpl", {
    ssh_public_key = var.ssh_public_key
  })
}
