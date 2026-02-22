terraform {
  required_version = "~> 1.9"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.96"
    }
  }
}

provider "proxmox" {
  endpoint = var.proxmox_endpoint
  insecure = var.proxmox_insecure
  # api_token is read automatically from the PROXMOX_VE_API_TOKEN environment variable.
  # Never set it here or in terraform.tfvars.

  ssh {
    agent    = true
    username = "root"
    # Requires the Proxmox root SSH key to be loaded in ssh-agent before running tofu.
    # Run: ssh-add ~/.ssh/<your-proxmox-key>
  }
}
