# ADR 002 — Use OpenTofu with the bpg/proxmox provider

**Status:** Accepted
**Date:** 2026-02-21
**Phase:** 0 (Repository bootstrap)

---

## Context

The Proxmox VMs need to be provisioned via IaC so that the cluster can be rebuilt from
code after a failure. The tool must integrate with Proxmox VE's API and support
cloud-init for initial VM configuration.

Two decisions are required:
1. Which IaC tool to use (Terraform vs OpenTofu)
2. Which Proxmox provider to use (bpg/proxmox vs telmate/proxmox)

---

## Decision

Use **OpenTofu** with the **bpg/proxmox** provider.

---

## Rationale

### OpenTofu over Terraform

In August 2023, HashiCorp changed Terraform's license from Mozilla Public License 2.0
to Business Source License 1.1 (BUSL). Under BUSL, using Terraform to offer a competing
commercial product requires a commercial license from HashiCorp. While this does not
affect personal use, the license change signals a direction that makes Terraform a risky
long-term choice for open-source portfolio projects.

OpenTofu is the open-source fork, initiated in response to the license change and adopted
by the OpenInfra Foundation (the organization behind OpenStack and Kata Containers).
OpenTofu maintains full compatibility with Terraform's HCL syntax and registry format.
All providers from the Terraform Registry work with OpenTofu without modification.

For a portfolio project on GitHub, using OpenTofu demonstrates:
- Awareness of the Terraform license change and its implications
- Comfort with the open-source ecosystem

**The HCL code is identical.** This is not a technical tradeoff — it is purely a
licensing and ecosystem choice.

### bpg/proxmox over telmate/proxmox

The `telmate/proxmox` provider was the original community provider but has seen declining
maintenance. As of early 2026, the `bpg/proxmox` provider (authored by @bpg) is the
actively recommended provider for both Proxmox 7.x and 8.x. Key advantages:

- Supports Proxmox VE API v7 and v8
- Proper cloud-init support via `proxmox_virtual_environment_file` resources
- The provider reads the VM IP address from the qemu-guest-agent (telmate requires a
  different approach)
- Actively maintained with frequent releases

**Critical bootstrap requirement:** The bpg provider requires:
1. A Proxmox API token (not username/password)
2. The Proxmox node must have a "snippets" content-type storage for cloud-init files
3. `qemu-guest-agent` must be installed and running inside the VM for the provider to
   read the VM's IP address

These requirements are documented in [docs/runbooks/bootstrap-proxmox.md](../runbooks/bootstrap-proxmox.md).

---

## Consequences

**Gained:**
- OSS license with no commercial restrictions.
- Full compatibility with Terraform ecosystem (providers, modules, registry).
- The bpg provider gives us a clean, declarative VM definition including cloud-init.

**Given up:**
- Terraform's commercial support and Terraform Cloud integration. Not relevant for a homelab.
- The Terraform registry URL format differs slightly from OpenTofu's; copy-pasted provider
  blocks from tutorials may reference `registry.terraform.io` instead of `registry.opentofu.org`.
  Both work — OpenTofu falls back to the Terraform registry for providers not yet in the
  OpenTofu registry.

**Operational notes:**
- The Proxmox API token (`PROXMOX_VE_API_TOKEN`) must be set as an environment variable
  before running `tofu apply`. It is never stored in the repository.
- The OpenTofu state file is stored locally outside the repository. Future work: migrate
  to an S3-compatible backend (MinIO) for state locking and remote access.

---

## References

- [OpenTofu](https://opentofu.org/)
- [bpg/proxmox provider docs](https://registry.terraform.io/providers/bpg/proxmox/latest/docs)
- [HashiCorp BUSL announcement](https://www.hashicorp.com/blog/hashicorp-adopts-business-source-license)
- [OpenTofu founding](https://opentofu.org/blog/the-opentofu-fork-is-now-available/)
