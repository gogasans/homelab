# homelab

A portfolio-grade homelab Kubernetes infrastructure built with real-world platform engineering
practices. Everything is in code. All decisions are documented. Mistakes are logged.

This repo is part of a personal learning journey — the goal is to build, break, fix, and
document everything so that the entire history is a useful artifact.

## What lives here

| Directory | Purpose |
|-----------|---------|
| [tofu/](tofu/) | OpenTofu (IaC) for provisioning VMs on Proxmox |
| [ansible/](ansible/) | OS hardening and k3s installation via Ansible |
| [kubernetes/](kubernetes/) | All Kubernetes manifests, reconciled by FluxCD |
| [docs/adr/](docs/adr/) | Architecture Decision Records |
| [docs/runbooks/](docs/runbooks/) | Operational procedures |
| [docs/lessons-learned/](docs/lessons-learned/) | Mistakes made and what was learned |

## Architecture overview

Two bare metal machines running Proxmox VE host one VM each:

```
Proxmox Host 1 (pve1)         Proxmox Host 2 (pve2)
┌──────────────────────┐       ┌──────────────────────┐
│  VM: k3s-cp-01       │       │  VM: k3s-worker-01   │
│  Role: Control Plane │       │  Role: Worker        │
│  OS: Ubuntu 24.04    │       │  OS: Ubuntu 24.04    │
└──────────────────────┘       └──────────────────────┘
         └────────────── LAN ──────────────┘
```

VMs are provisioned by OpenTofu, configured by Ansible, and the cluster is managed
entirely via GitOps with FluxCD.

**Known limitation:** A single control plane node has no HA. See [ADR 009](docs/adr/009-single-cp-not-ha.md).

## Technology stack

| Layer | Tool | Why |
|-------|------|-----|
| Hypervisor | Proxmox VE | Bare metal hosts |
| VM provisioning | OpenTofu + bpg/proxmox | OSS Terraform fork; actively maintained provider |
| OS config | Ansible | Idempotent, auditable |
| Kubernetes | k3s | Single binary, lowest resource overhead |
| GitOps | FluxCD v2 | Lightweight, git-native, pull-based |
| Secrets | HashiCorp Vault + External Secrets Operator | Centralized, audited, fine-grained — no secrets ever touch git |
| Ingress | Traefik v3 | Supports Gateway API; managed by FluxCD |
| TLS | cert-manager + Let's Encrypt | DNS-01 wildcard certs |
| Storage | local-path → Longhorn | Start simple, migrate to replicated |
| Observability | kube-prometheus-stack + Loki + Alloy | Full metrics + logs |

## Prerequisites

First, install [mise](https://mise.jdx.dev) if you don't have it:

```bash
brew install mise
echo 'eval "$(mise activate zsh)"' >> ~/.zshrc
source ~/.zshrc
```

Then install all tools at pinned versions (including [Task](https://taskfile.dev), the project's task runner) and verify:

```bash
mise install      # installs all tools from .tool-versions, including task
task setup        # installs uv-managed tools (ansible-lint)
task prereqs      # verifies everything is installed correctly
```

Run `task --list` to see all available tasks.

## Getting started

The bootstrap process has multiple phases. Each phase has a verification step before
proceeding. Read the full setup guides before running anything.

1. **Prepare Proxmox** — follow [docs/runbooks/bootstrap-proxmox.md](docs/runbooks/bootstrap-proxmox.md)
   to create the API token and cloud-init VM template. This is the only manual step.

2. **Provision VMs**
   ```bash
   export PROXMOX_VE_API_TOKEN="your-token-id=your-secret-token"
   task tofu-plan   # review what will be created
   task tofu-apply  # create the VMs
   ```

3. **Install k3s**
   ```bash
   task ansible-run
   ```

4. **Bootstrap FluxCD**
   ```bash
   export GITHUB_TOKEN="your-github-personal-access-token"
   task flux-bootstrap
   ```

5. **Initialize Vault** (one-time manual step — output goes to your password manager)
   ```bash
   task vault-unseal   # after Vault pod starts sealed
   ```
   Follow [docs/runbooks/vault-init.md](docs/runbooks/vault-init.md) for the full sequence.

After step 5, all further infrastructure and application changes are deployed by pushing
to this repository. Secrets are written directly to Vault via the CLI — never to files.

## Day-to-day operations

```bash
task flux-status       # show status of all Flux resources
task flux-reconcile    # force reconcile (useful after a manual push)
task vault-status      # check whether Vault is sealed
task vault-unseal      # unseal Vault after a pod restart
task lint              # run all linters locally before opening a PR
```

## Repository conventions

- **IaC:** all infrastructure changes go through PRs. No manual changes to Proxmox or the cluster without a follow-up PR. See [deployment-standards](.claude/rules/deployment-standards.md) (inherited from project root).
- **Secrets:** stored in HashiCorp Vault only. No Kubernetes `Secret` manifests in git. No encrypted files in git. See [Vault conventions](.claude/rules/vault-conventions.md).
- **ADRs:** every significant technology choice has a written [Architecture Decision Record](docs/adr/).
- **Lessons learned:** mistakes and surprises are documented in [docs/lessons-learned/](docs/lessons-learned/).

## Support

This is a personal project. For questions, open an issue on GitHub.
