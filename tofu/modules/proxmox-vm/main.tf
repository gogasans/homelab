terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.96"
    }
  }
}

resource "proxmox_virtual_environment_file" "cloud_init" {
  content_type = "snippets"
  datastore_id = var.snippets_storage
  node_name    = var.proxmox_node

  source_raw {
    data      = var.cloud_init_config
    file_name = "${var.vm_name}.yaml"
  }
}

resource "proxmox_virtual_environment_vm" "vm" {
  name        = var.vm_name
  description = var.description
  node_name   = var.proxmox_node
  vm_id       = var.vm_id

  clone {
    vm_id     = var.template_id
    node_name = var.template_node
    full      = true
  }

  agent {
    enabled = true
  }

  cpu {
    cores = var.cores
    type  = "x86-64-v2-AES"
  }

  memory {
    dedicated = var.memory_mb
  }

  # OS disk — resized from the template
  disk {
    datastore_id = var.vm_disk_storage
    interface    = "scsi0"
    size         = var.os_disk_gb
    discard      = "on"
    file_format  = "raw"
  }

  # Data disk — used by Longhorn for replicated storage
  disk {
    datastore_id = var.vm_disk_storage
    interface    = "scsi1"
    size         = var.data_disk_gb
    discard      = "on"
    file_format  = "raw"
  }

  network_device {
    bridge = var.network_bridge
    model  = "virtio"
  }

  initialization {
    datastore_id = var.vm_disk_storage

    ip_config {
      ipv4 {
        address = var.ip_address
        gateway = var.gateway
      }
    }

    dns {
      servers = var.dns_servers
    }

    user_data_file_id = proxmox_virtual_environment_file.cloud_init.id
  }

  operating_system {
    type = "l26"
  }

  serial_device {}

  lifecycle {
    ignore_changes = [
      # MAC address is assigned by Proxmox on creation; ignore subsequent drift
      network_device[0].mac_address,
    ]
  }
}
