## Summary

<!-- What does this PR do? Be specific about what changed. -->

## Motivation

<!-- Why is this change needed? Link to any relevant issues or ADRs. -->

## Changes

<!-- Bullet list of specific changes made -->
-
-

## Testing

<!-- How was this tested? What commands were run? What output verified correctness? -->

- [ ] `tofu plan` output reviewed (paste or attach if infrastructure changes)
- [ ] Ansible playbook ran successfully (`ansible-playbook playbooks/site.yaml`)
- [ ] Ansible idempotency verified (ran twice; second run showed 0 changes)
- [ ] Flux reconciled successfully (`flux get all -A` output reviewed)
- [ ] Relevant Grafana dashboards checked post-deployment

## Risk Assessment

- **Risk level:** LOW / MEDIUM / HIGH
- **Blast radius:** <!-- What is affected if this fails? -->

## Rollback Plan

<!-- Exact steps to revert if this causes issues. Required for MEDIUM/HIGH risk. -->
1.
2.

## Checklist

- [ ] No secrets committed (all sensitive values live in Vault; nothing secret in git)
- [ ] Image/chart/tool versions are pinned (no `latest` tags)
- [ ] README or ADR updated if this introduces a new component or significant change
- [ ] Lessons learned updated if this involved a mistake or non-obvious discovery
