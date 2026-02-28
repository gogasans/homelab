.PHONY: help lint lint-tofu lint-ansible lint-k8s prereqs setup \
        tofu-plan tofu-apply tofu-destroy \
        ansible-run ansible-check \
        flux-bootstrap flux-status \
        vault-unseal vault-status

HOMELAB_ENV   := environments/homelab
TOFU_DIR      := tofu/$(HOMELAB_ENV)
ANSIBLE_DIR   := ansible
K8S_DIR       := kubernetes
CLUSTER       := homelab

help: ## Show this help message
	@grep -E '^[a-zA-Z_-]+:.*##' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*##"}; {printf "  \033[36m%-22s\033[0m %s\n", $$1, $$2}'

# ── Prerequisites ───────────────────────────────────────────────────────────

setup: ## Install all prerequisites (mise tools + uv tools)
	mise install
	uv tool install ansible-lint==25.1.3 --with ansible==11.2.0 --python 3.12

prereqs: ## Verify all required tools are installed at pinned versions
	@scripts/check-prerequisites.sh

# ── Linting ─────────────────────────────────────────────────────────────────

lint: lint-tofu lint-ansible lint-k8s ## Run all linters

lint-tofu: ## Lint OpenTofu code (fmt-check + validate + trivy)
	@echo "==> Checking OpenTofu formatting..."
	tofu -chdir=$(TOFU_DIR) fmt -check -recursive
	@echo "==> Validating OpenTofu configuration..."
	tofu -chdir=$(TOFU_DIR) init -backend=false -input=false
	tofu -chdir=$(TOFU_DIR) validate
	@echo "==> Scanning OpenTofu config with trivy..."
	trivy config tofu/

lint-ansible: ## Lint Ansible playbooks and roles
	@echo "==> Linting Ansible..."
	cd $(ANSIBLE_DIR) && ansible-lint --profile production

lint-k8s: ## Lint Kubernetes manifests (kubeconform + kube-linter)
	@echo "==> Validating Kubernetes manifests with kubeconform..."
	kubeconform -strict -summary \
		-kubernetes-version 1.32.0 \
		-ignore-missing-schemas \
		$(K8S_DIR)/
	@echo "==> Linting Kubernetes manifests with kube-linter..."
	kube-linter lint $(K8S_DIR)/ --config .kube-linter.yaml

# ── OpenTofu ────────────────────────────────────────────────────────────────

tofu-plan: ## Plan OpenTofu changes (requires PROXMOX_VE_API_TOKEN env var)
	@scripts/tofu-plan.sh

tofu-apply: ## Apply OpenTofu changes (requires PROXMOX_VE_API_TOKEN env var)
	tofu -chdir=$(TOFU_DIR) apply

tofu-destroy: ## Destroy OpenTofu-managed resources (DANGEROUS)
	@echo "WARNING: This will destroy all VMs. Press Ctrl+C to cancel, Enter to continue."
	@read
	tofu -chdir=$(TOFU_DIR) destroy

# ── Ansible ─────────────────────────────────────────────────────────────────

ansible-run: ## Run the full site.yaml playbook
	cd $(ANSIBLE_DIR) && ansible-playbook playbooks/site.yaml

ansible-check: ## Dry-run the site.yaml playbook (check mode)
	cd $(ANSIBLE_DIR) && ansible-playbook --check playbooks/site.yaml

ansible-teardown: ## Remove k3s from all nodes (rollback)
	@echo "WARNING: This will remove k3s from all nodes. Press Ctrl+C to cancel, Enter to continue."
	@read
	cd $(ANSIBLE_DIR) && ansible-playbook playbooks/99-teardown.yaml

# ── FluxCD ──────────────────────────────────────────────────────────────────

flux-bootstrap: ## Bootstrap FluxCD (requires GITHUB_TOKEN env var)
	@scripts/bootstrap.sh

flux-status: ## Show status of all Flux resources
	flux get all -A

flux-reconcile: ## Force reconcile all Flux Kustomizations
	flux reconcile kustomization flux-system --with-source

# ── Vault ────────────────────────────────────────────────────────────────────

vault-unseal: ## Unseal Vault after a pod restart (interactive — prompts for unseal keys)
	@scripts/vault-unseal.sh

vault-status: ## Show Vault seal status and cluster members
	@kubectl exec -n vault vault-0 -- vault status 2>/dev/null || \
		echo "Could not reach Vault. Check: kubectl get pods -n vault"
