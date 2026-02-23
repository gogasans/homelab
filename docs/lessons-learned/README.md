# Lessons Learned

This is a living document. Every time something breaks, a decision turns out to be wrong,
or something non-obvious is discovered, it gets written down here.

The goal: future-me (and anyone reading this repo) can avoid making the same mistakes,
and can understand why things look the way they do even if the code doesn't explain it.

---

## Format

Each entry follows this structure:

```
### [Date] Short description of the mistake or discovery

**Phase:** Which phase this happened in
**What happened:** What was observed
**Why it happened:** Root cause
**How it was fixed:** The resolution
**What to remember:** The lesson in one or two sentences
```

---

## Entries

### 2026-02-22 — Use a dynamic inventory script instead of a static hosts file for tofu-managed infra

**Phase:** Phase 1 / Ansible setup
**What happened:** `ansible/inventory/hosts.yaml` was written with hardcoded IPs
(`192.168.10.120`, `192.168.10.121`). These are already defined in the gitignored
`terraform.tfvars` and exported as OpenTofu outputs. Committing them to the repo creates
a sync hazard and leaks private network topology.
**Why it happened:** The static hosts file is the simplest starting point, but it duplicates
information that OpenTofu already owns.
**How it was fixed:** Replaced `hosts.yaml` with `inventory/tofu_inventory.py`, a Python
dynamic inventory script that calls `tofu output -json` at runtime and maps the outputs to
Ansible's inventory JSON format. `ansible.cfg` now points to the inventory directory
(`inventory/`) instead of a specific file, so Ansible discovers the script automatically.
**What to remember:** For any infra managed by OpenTofu, drive Ansible inventory from
`tofu output` — not from a second source of truth. The `community.general.terraform_state`
inventory plugin was considered but rejected: `bpg/proxmox` stores IPs in deeply nested
state attributes with CIDR notation, and the plugin does not filter resource types, so
cloud-init file resources would also appear as inventory hosts.

---

### 2026-02-22 — Use mise instead of asdf for tool version management

**Phase:** Phase 0 / setup
**What happened:** `asdf` requires manually registering a plugin for each tool before `asdf install`
can run. With 9 tools, this means 9 separate `asdf plugin add` commands — more friction than needed
for onboarding.
**Why it happened:** `asdf`'s plugin model is opt-in per tool; it does not auto-discover tools from
`.tool-versions`.
**How it was fixed:** Switched to `mise`, a drop-in replacement that reads the same `.tool-versions`
format but handles plugin resolution automatically. The entire setup becomes two commands:
`brew install mise` and `mise install`.
**What to remember:** `mise` is strictly better for this use case — same `.tool-versions` format,
no plugin management, faster installs. Prefer `mise` over `asdf` for new projects.

---

## Known Pitfalls (pre-populated before they happen)

These are documented in advance based on known gotchas in the tools used. When one of
these is encountered, move it to the Entries section above and fill in the specifics.

### qemu-guest-agent must be running before OpenTofu can read the VM IP

**Tool:** bpg/proxmox OpenTofu provider
**Symptom:** `tofu apply` hangs waiting for the VM IP address. The VM appears to have
started in the Proxmox UI.
**Cause:** The `bpg/proxmox` provider reads the VM's IP address from the qemu-guest-agent
running inside the VM. If the cloud-init did not install or start the agent, the provider
waits indefinitely.
**Fix:** Ensure `qemu-guest-agent` is included in the cloud-init packages list and
the systemd service is enabled.

---

### k3s join token must never be committed to git

**Tool:** k3s + Ansible
**Location:** `/var/lib/rancher/k3s/server/node-token` on the control plane
**Cause:** The join token authenticates worker nodes to the cluster. If committed, anyone
with repo access can join unauthorized nodes.
**Fix:** Retrieve the token at runtime in Ansible using `ansible.builtin.slurp`. Register
it as an Ansible variable scoped to the current playbook run.

---

### FluxCD dependsOn is about reconciliation order, not Kubernetes readiness

**Tool:** FluxCD
**Symptom:** A Kustomization that depends on another finishes, but the resources it
deploys fail because a CRD from the first Kustomization is not yet registered.
**Cause:** `dependsOn` means Flux waits for the parent Kustomization's `Ready` status
condition before starting reconciliation of the child. However, a Kustomization can
report `Ready` as soon as its manifests are applied — before the CRDs they define are
fully registered in the Kubernetes API.
**Fix:** Use `healthChecks` in the parent Kustomization to wait for specific resources
(Deployments, etc.) to be ready before the child starts. Or add a small `retryInterval`
on the child Kustomization so it self-heals when CRDs become available.

---

### Let's Encrypt production rate limits are strict

**Tool:** cert-manager + Let's Encrypt
**Limit:** 5 certificates per registered domain per week (production issuer)
**Symptom:** Certificate requests start failing with "too many certificates already
issued for" errors. The cluster cannot get TLS certificates.
**Fix:** Always test with the `letsencrypt-staging` ClusterIssuer first. Staging has
much more permissive rate limits. Only switch to production after confirming the DNS-01
challenge works correctly.

---

### Vault seals itself on every pod restart — the cluster is degraded until unsealed

**Tool:** HashiCorp Vault
**Symptom:** After a node reboot or Vault upgrade, apps fail to start. ESO shows errors.
`kubectl get clustersecretstore` shows the store is not ready.
**Cause:** Vault's security model requires manual unseal after every pod restart. A sealed
Vault cannot serve any requests. ESO cannot pull secrets, so apps waiting for secrets cannot start.
**Fix:** Run `make vault-unseal` and enter 3 of the 5 unseal keys from your password manager.
ESO will resume syncing automatically. Apps will restart and pick up their secrets.
**What to remember:** After any planned Vault downtime (upgrades, node maintenance), schedule
time immediately after to unseal Vault. Add a Grafana alert for Vault sealed status.

---

### Vault init output is shown exactly once — save it immediately

**Tool:** HashiCorp Vault
**Symptom:** N/A — this is a prevention note, not a symptom.
**Cause:** `vault operator init` generates the unseal keys and root token and displays them once.
If you close the terminal or lose the output, the keys are gone permanently. Vault's data is
then accessible only if you have a Raft snapshot from before the loss.
**Fix (prevention):** The `scripts/vault-init.sh` script pauses after initialization and waits
for you to confirm you have saved the output before continuing.
**What to remember:** Treat the vault init output like the seed phrase for a crypto wallet.
Save it immediately to your password manager. There is no "forgot my unseal keys" recovery option.

---

### Vault KV v2 policy paths include /data/ but the CLI does not show it

**Tool:** HashiCorp Vault KV v2
**Symptom:** ESO gets "permission denied" errors even after creating a Vault policy and role.
**Cause:** KV v2 internally stores secrets under `/data/` paths. The Vault CLI addresses them as
`secret/myapp`, but the actual API path — and the path you must use in HCL policies — is
`secret/data/myapp`. A policy written without `/data/` will not match any KV v2 secret.
**Fix:** Always include `/data/` in Vault policy paths:
```hcl
# Correct
path "secret/data/cert-manager" { capabilities = ["read"] }

# Wrong — will result in "permission denied" at runtime
path "secret/cert-manager" { capabilities = ["read"] }
```
**What to remember:** The CLI hides the `/data/` layer for UX. Policies do not.

---

### Vault Kubernetes auth must be reconfigured after cluster rebuild

**Tool:** HashiCorp Vault — Kubernetes auth method
**Symptom:** After rebuilding the cluster, ESO's ClusterSecretStore stays in an error state.
Vault logs show "invalid JWT" or "Issuer mismatch" errors.
**Cause:** The Kubernetes auth method stores the cluster's CA certificate and API server URL.
After a full cluster rebuild, the CA cert changes (new cluster = new CA), so Vault rejects
every authentication attempt from pods in the new cluster.
**Fix:** Re-run the Kubernetes auth configuration step from `scripts/vault-init.sh`:
```bash
vault write auth/kubernetes/config \
  kubernetes_host="<new cluster API URL>" \
  kubernetes_ca_cert="<new cluster CA cert>"
```
**What to remember:** Vault's Kubernetes auth is bound to a specific cluster identity.
Full cluster rebuilds require Vault auth reconfiguration. See vault-disaster-recovery.md.

---

### Traefik v3 uses a different API version than v2

**Tool:** Traefik
**Symptom:** IngressRoute resources are applied but Traefik does not pick them up.
**Cause:** Traefik v3 changed the API group from `traefik.containo.us` (v2) to
`traefik.io` (v3). Community tutorials, StackOverflow answers, and blog posts frequently
show the old v2 syntax.
**Fix:** Use `apiVersion: traefik.io/v1alpha1` in all IngressRoute manifests.
Check the Traefik version: `kubectl get helmrelease -n traefik` and cross-reference
with the Traefik changelog.
