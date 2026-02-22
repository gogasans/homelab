# Vault policy: external-secrets-read
# Grants ESO read access to all secrets under the secret/ KV v2 engine.
#
# Note: KV v2 paths in policies include /data/ even though the CLI and API
# do not show it. This is a common source of "permission denied" errors.
# Reference: https://developer.hashicorp.com/vault/docs/secrets/kv/kv-v2#acl-rules

# Allow listing the top-level paths (required for ESO to discover available secrets)
path "secret/metadata/*" {
  capabilities = ["list"]
}

# Allow reading any secret value
# Scope can be narrowed to specific paths as the cluster matures.
# For now, a broad policy simplifies bootstrapping.
path "secret/data/*" {
  capabilities = ["read"]
}
