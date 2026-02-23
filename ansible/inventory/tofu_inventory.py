#!/usr/bin/env python3
"""Ansible dynamic inventory — reads OpenTofu outputs for the homelab environment.

Implements the Ansible dynamic inventory protocol:
  tofu_inventory.py --list   Return full inventory JSON (with _meta.hostvars)
  tofu_inventory.py --host   Not used; hostvars are served via _meta in --list

Requires:
  - `tofu` in PATH
  - `tofu apply` completed at least once (state file must exist)

State file location: tofu/environments/homelab/terraform.tfstate (relative to repo root)
"""

import json
import os
import subprocess
import sys

# Resolve the tofu environment directory relative to this script's location.
# Script lives at: ansible/inventory/tofu_inventory.py
# Tofu env lives at: tofu/environments/homelab/
_SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
_REPO_ROOT = os.path.normpath(os.path.join(_SCRIPT_DIR, "..", ".."))
TOFU_DIR = os.path.join(_REPO_ROOT, "tofu", "environments", "homelab")


def get_tofu_outputs() -> dict:
    state_file = os.path.join(TOFU_DIR, "terraform.tfstate")
    if not os.path.exists(state_file):
        print(
            f"Error: tofu state not found at {state_file}\n"
            "Run 'make tofu-apply' first.",
            file=sys.stderr,
        )
        sys.exit(1)

    try:
        result = subprocess.run(
            ["tofu", f"-chdir={TOFU_DIR}", "output", "-json"],
            capture_output=True,
            text=True,
            check=True,
        )
    except FileNotFoundError:
        print("Error: 'tofu' binary not found. Run 'mise install'.", file=sys.stderr)
        sys.exit(1)
    except subprocess.CalledProcessError as e:
        print(f"Error: 'tofu output' failed:\n{e.stderr}", file=sys.stderr)
        sys.exit(1)

    return json.loads(result.stdout)


def build_inventory() -> dict:
    outputs = get_tofu_outputs()

    try:
        cp_ip = outputs["control_plane_ip"]["value"]
        worker_ip = outputs["worker_ip"]["value"]
    except KeyError as e:
        print(
            f"Error: expected tofu output {e} not found. "
            "Check tofu/environments/homelab/outputs.tf.",
            file=sys.stderr,
        )
        sys.exit(1)

    return {
        "control_plane": {
            "hosts": ["k3s-cp-01"],
        },
        "workers": {
            "hosts": ["k3s-worker-01"],
        },
        "_meta": {
            "hostvars": {
                "k3s-cp-01": {"ansible_host": cp_ip},
                "k3s-worker-01": {"ansible_host": worker_ip},
            }
        },
    }


def main() -> None:
    if "--list" in sys.argv:
        print(json.dumps(build_inventory(), indent=2))
    elif "--host" in sys.argv:
        # Hostvars are returned via _meta in --list; individual host calls return empty.
        print(json.dumps({}))
    else:
        print(
            "Usage: tofu_inventory.py --list | --host <hostname>",
            file=sys.stderr,
        )
        sys.exit(1)


if __name__ == "__main__":
    main()
