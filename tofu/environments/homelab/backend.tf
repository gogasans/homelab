terraform {
  backend "local" {
    # State is stored at tofu/environments/homelab/terraform.tfstate.
    # That path is covered by the *.tfstate rule in .gitignore — it is never committed.
    # Future work: migrate to an S3-compatible backend (MinIO) for remote state + locking.
    path = "terraform.tfstate"
  }
}
