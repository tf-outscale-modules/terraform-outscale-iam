# Tasks

Standards to cite in the final summary: `terraform-versioning`, `terraform-providers`, `terraform-variables`, `terraform-security`, `terraform-testing`, `quality-security`, `quality-production-readiness`.

## 1. Provider floor

- [x] 1.1 Change `~> 1.8` to `~> 1.9` in `versions.tf`, `examples/complete/versions.tf` and `examples/minimal/versions.tf`; leave `required_version` untouched. Done when `grep -rn '~> 1.8' --include=versions.tf .` returns nothing and `tofu init -backend=false -upgrade && tofu validate` passes at the root.

## 2. Variables (`variables.tf`)

- [x] 2.1 Add `create_api_access_policy`, `create_api_access_rules`, `create_cas` (`bool`, default `true`, description) in the "Conditional Creation Variables" section. Done when `tofu validate` passes and tflint reports no undocumented/untyped variable.
- [x] 2.2 Add `api_access_policy` (object per design Decision 8, `default = null`) with the three validations (integer range 0..3153600000; trusted env needs max > 0; secure mode needs trusted env). Done when unit tests 5.2 pass.
- [x] 2.3 Add `cas` (`map(object({ca_pem = string, description = optional(string)}))`, default `{}`) with PEM-certificate and no-`PRIVATE KEY` validations; no `sensitive`. Done when unit tests 5.4 pass.
- [x] 2.4 Add `api_access_rules` (`map(object)` with `set(string)` fields, default `{}`) with validations: IP or CA required, `cns` needs a CA, canonical CIDR, `ca_keys` subset of `keys(var.cas)`, `ca_ids` start with `ca-`, `ca_keys` needs `create_cas = true`. Done when unit tests 5.3 pass.

## 3. Resources (`main.tf`)

- [x] 3.1 Add `outscale_ca.this` (`for_each = var.create_cas ? var.cas : {}`), `description` passed as given (null when unset). Done when a plan with one CA shows one `outscale_ca.this["<key>"]`.
- [x] 3.2 Add `outscale_api_access_rule.this` (`for_each = var.create_api_access_rules ? var.api_access_rules : {}`) sending `ip_ranges`, `ca_ids` (merge of `ca_ids` and `outscale_ca.this[key].ca_id` for `ca_keys`), `cns` as `set(string)` or `null` when empty, `description` null when unset. Done when plan shows the CA created before the rule and the rule's `ca_ids` unknown until apply.
- [x] 3.3 Add the singleton `local` and `outscale_api_access_policy.this` (`for_each = local.api_access_policies`, key `this`) with `depends_on = [outscale_api_access_rule.this, outscale_access_key.this]` and `require_trusted_env_secure_mode` sent as given (null when unset). Done when plan shows `outscale_api_access_policy.this["this"]` only when the input is set and the toggle is `true`.
- [x] 3.4 Add the `check` blocks `api_access_trusted_env_rules_have_ca` and `api_access_expiry_cap_keys_have_expiration` (design Decision 3), each message naming the offending map keys. Done when unit tests 5.5 show the warnings via `expect_failures = [check.<name>]`.

## 4. Outputs (`outputs.tf`)

- [x] 4.1 Add `api_access_policy`, `api_access_rules`, `api_access_rule_ids`, `cas`, `ca_ids` (descriptions, none sensitive, `{}` when nothing is created). Done when unit tests 5.1 assert the empty-map and populated cases and tflint `terraform_documented_outputs` passes.

## 5. Unit tests (`tests/main.tftest.hcl`, new; `mock_provider "outscale" {}`, `command = plan`)

- [x] 5.1 Opt-in: defaults plan zero API access resources and all five outputs `{}`; each `create_*` toggle `false` suppresses its resource; existing inputs (a user + a policy) plan unchanged. Done when `tofu test` passes these runs.
- [x] 5.2 Policy: valid cap-only, trusted env, secure mode plans; `expect_failures = [var.api_access_policy]` for `3153600001`, `-1`, `1.5`, trusted env with `0`, secure mode without trusted env.
- [x] 5.3 Rules: valid IP-only, CA-key and existing `ca_ids` rules (CA-key rule depends on the CA); `expect_failures = [var.api_access_rules]` for empty rule, `cns` without CA, bare IP `192.0.2.7`, non-canonical `192.0.2.7/24`, unknown `ca_keys`, `ca_ids` not starting with `ca-`; a rule with the same `ip_ranges` in another order plans identically.
- [x] 5.4 CAs: valid certificate PEM plans; `expect_failures = [var.cas]` for a non-PEM string and for a value containing `PRIVATE KEY`. Use a clearly fake public test certificate, never a real key.
- [x] 5.5 Checks: trusted env with a CA-less rule warns; cap `> 0` with an `access_keys` entry lacking `expiration_date` warns; safe combinations produce no warning.
- [x] 5.6 Run `tofu test`. Done when every run passes and the validation cases each have a run with `expect_failures`.

## 6. Examples

- [x] 6.1 Update `examples/complete/main.tf` (and `variables.tf`/`outputs.tf` as needed): one CA from `file("${path.module}/ca/example-ca.crt")` (public throw-away certificate; `.crt` because `*.pem` is gitignored), one rule with a documentation CIDR (`192.0.2.0/24` and a comment telling the user to replace it with their own egress range) and the CA, and an `api_access_policy` with a 1-year cap and `require_trusted_env = false`; comments warn about account-wide scope and lock-out. Add the new outputs to `examples/complete/outputs.tf`. Done when `tofu init -backend=false && tofu validate` passes in the example.
- [x] 6.2 Confirm `examples/minimal` needs no new inputs (opt-in) and validates with the new provider pin. Done when `tofu validate` passes there.

## 7. Documentation

- [x] 7.1 README (outside `BEGIN_TF_DOCS`/`END_TF_DOCS`): features, requirements/compat table showing provider `~> 1.9` and why, a usage snippet, limitations (singleton policy, no-op destroy, Optional+Computed sets cannot be cleared, CIDR-only). Done when `git diff README.md` shows no edit inside the markers.
- [x] 7.2 `SECURITY.md`: new section "API access control": account-wide scope, lock-out scenarios and apply order, the "what lands in state" additions (public CA PEM, IP ranges, policy values), why `ca_pem` is public/not sensitive and the `PRIVATE KEY` guard, least-privilege action list confirmed from https://docs.outscale.com/api (EIM actions for `ApiAccessPolicy`, `ApiAccessRule`, `Ca`). Done when each Decision 3 and 6 item appears.
- [ ] 7.3 `SECURITY.md`: disable procedure (apply `0`/`false`, then remove the input) and recovery. Verify on a real account whether `UpdateApiAccessPolicy` with login/password bypasses API access rules and trusted sessions; write the verified path, or "recovery path unverified: contact Outscale support" if it cannot be verified. Done when the section states exactly one of the two.
- [x] 7.4 `TESTING.md`: add `tofu test` and the new validation cases. Done when the file lists them.

## 8. Validation and release

- [x] 8.1 Run `tofu fmt -recursive`, `tofu init -backend=false && tofu validate` (root and both examples), `tflint --recursive`, `tofu test`. Done when all exit 0.
- [x] 8.2 Run `terraform-docs` (via `pre-commit run -a`) to regenerate the README tables, then `pre-commit run -a` until clean. Done when it exits 0 and a second run changes nothing.
- [ ] 8.3 Full integration against a throw-away Outscale account (plan + apply + second plan + destroy) of `examples/complete` and `examples/minimal`, with a source IP covered by the example rule. Done when: the second plan is empty (confirms CIDR/set normalisation and `ca_pem`), IPv6 CIDR acceptance is recorded (keep or restrict the validation), a CA referenced by a rule is destroyed after the rule, the policy is disabled explicitly before removal, and the README compatibility table records the tested provider/OpenTofu/Terraform versions.
- [ ] 8.4 Commit with a subject that reads as the CHANGELOG line and states the major bump, e.g. `Add API access policy, rules and CA management (requires provider ~> 1.9, major)`; do not edit `CHANGELOG.md` by hand (git-cliff). Done when `git log -1 --format=%s` shows it and `mise run changelog` renders it under the next version.
- [x] 8.5 Run `openspec validate add-api-access-policy-and-rules`. Done when it reports the change valid; archive afterwards with `/openspec-archive-change` to create `openspec/specs/api-access/spec.md`.

## Workflow follow-up

- Release tag `v2.0.0` after merge (MAJOR per `terraform-versioning`; the MINOR alternative was rejected).
