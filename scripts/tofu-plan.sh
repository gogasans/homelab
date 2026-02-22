#!/usr/bin/env bash
# tofu-plan.sh
# Runs `tofu plan` for the homelab environment with the correct working directory.
# Validates that required environment variables are set before running.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
TOFU_DIR="$ROOT_DIR/tofu/environments/homelab"

# Check required environment variables
MISSING=0

if [ -z "${PROXMOX_VE_API_TOKEN:-}" ]; then
  echo "Error: PROXMOX_VE_API_TOKEN is not set."
  echo "Set it with: export PROXMOX_VE_API_TOKEN='user@pam!token=secret'"
  MISSING=1
fi

if [ -z "${PROXMOX_VE_ENDPOINT:-}" ]; then
  echo "Error: PROXMOX_VE_ENDPOINT is not set."
  echo "Set it with: export PROXMOX_VE_ENDPOINT='https://<proxmox-ip>:8006'"
  MISSING=1
fi

if [ $MISSING -eq 1 ]; then
  exit 1
fi

# Check for tfvars file
if [ ! -f "$TOFU_DIR/terraform.tfvars" ]; then
  echo "Error: tofu/environments/homelab/terraform.tfvars not found."
  echo "Copy the example and fill in your values:"
  echo "  cp tofu/environments/homelab/terraform.tfvars.example tofu/environments/homelab/terraform.tfvars"
  echo "  \$EDITOR tofu/environments/homelab/terraform.tfvars"
  echo ""
  echo "Note: terraform.tfvars is in .gitignore and will never be committed."
  exit 1
fi

echo "Running tofu plan in $TOFU_DIR"
echo ""
tofu -chdir="$TOFU_DIR" plan
