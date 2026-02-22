output "control_plane_ip" {
  description = "IPv4 address of the k3s control plane VM (k3s-cp-01)."
  value       = module.cp.ipv4_address
}

output "worker_ip" {
  description = "IPv4 address of the k3s worker VM (k3s-worker-01)."
  value       = module.worker.ipv4_address
}
