# Design

## Context

Current module (v1.1.0): `main.tf` has users, groups, policies, policy versions and access keys, each gated by `for_each = var.create_X ? var.X : {}` and labelled `this`; `versions.tf` pins `outscale/outscale ~> 1.8`, `required_version >= 1.10.0`; no `tests/` directory and `openspec/config.yaml` declares no `references:` for the standards stores (the stores `quality`, `repository`, `terraform` are registered on this machine and were read directly with `openspec show <id> --type spec --store <store>`). See `proposal.md` for motivation and the release classification.

Provider facts, verified against the provider schemas (`schema.json` of v1.8.0 and v1.9.0), the v1.9.0 docs and the v1.9.0 source (`internal/services/oapi/resource_api_access_policy.go`, `resource_api_access_rule.go`, `resource_ca.go`):

| Resource | Attribute | Config | Notes |
|---|---|---|---|
| `outscale_api_access_policy` | `max_access_key_expiration_seconds` | Required, number | provider validator `Between(0, 3153600000)` |
| | `require_trusted_env` | Required, bool | provider `ValidateConfig`: `true` with `max_access_key_expiration_seconds == 0` is an error |
| | `require_trusted_env_secure_mode` | Optional + Computed, bool, default `false` | **new in 1.9.0**; docs: needs `require_trusted_env = true` and max > 0; the provider does not validate this combination |
| | `id`, `request_id` | Computed | |
| | `timeouts` | create/read/update | not exposed by the module |
| | (delete) | | `Delete` is an empty function: destroy does nothing server-side |
| `outscale_api_access_rule` | `ip_ranges` | Optional + Computed, set(string) | each item IP or CIDR (provider validator) |
| | `ca_ids` | Optional + Computed, set(string) | |
| | `cns` | Optional + Computed, set(string) | docs: requires `ca_ids` |
| | `description` | Optional + Computed, string | |
| | `api_access_rule_id`, `id`, `request_id` | Computed | `api_access_rule_id`/`id` use `UseStateForUnknown` |
| | (update) | | in-place; only arguments that are set are sent; no `ForceNew` |
| `outscale_ca` | `ca_pem` | Required, string | `RequiresReplace` (ForceNew) |
| | `description` | Optional + Computed | |
| | `ca_id`, `ca_fingerprint`, `id`, `request_id` | Computed | |

`outscale_api_access_policy`, `outscale_api_access_rule` and `outscale_ca` exist unchanged in 1.8.0 except for `require_trusted_env_secure_mode`. Registry docs: https://registry.terraform.io/providers/outscale/outscale/latest/docs/resources/api_access_policy, `.../api_access_rule`, `.../ca`. Outscale user guide: https://docs.outscale.com/en/userguide/About-Your-API-Access-Policy.html. Verified against provider **1.9.0**; constraint `~> 1.9`.

Distinction to keep in documentation: provider 1.9.0 deprecated **x509 authentication of the provider** to the Outscale API. That concerns how Terraform logs in, and the module has no `provider {}` block. `outscale_ca` registers a Certificate Authority that API access rules use to accept **client certificates of API callers**; it is unaffected.

## Goals / Non-Goals

**Goals:**
- Manage the account API access policy, API access rules and CAs from the module, opt-in, with validation that fails fast and `check` warnings for lock-out-prone setups.
- Idempotence: a second plan after apply is empty.
- Document account-wide scope, lock-out risk, recovery and the no-op destroy.

**Non-Goals:**
- Data sources for existing policy/rules/CAs; importing existing ones (documented as manual `import` for rules and CAs; the policy needs none, see Decision 2).
- Exposing resource `timeouts`.
- Raising `required_version` (the repo's `>= 1.10.0` is below the `>= 1.11.0` of `terraform-providers`; that is a separate pre-existing gap, not changed here).
- Computing the caller's egress IP or testing lock-out against the live API.

## Decisions

### 1. Inputs: one singleton object, two maps, `create_*` toggles

- `api_access_policy`: `object({ max_access_key_expiration_seconds = number, require_trusted_env = bool, require_trusted_env_secure_mode = optional(bool) })`, `default = null`. The two Required provider arguments are required attributes (no invented defaults, `terraform-variables` "Optional attribute with an invented default"); the 1.9.0 attribute defaults to `null` = "provider default" and is only sent when set.
- `api_access_rules`: `map(object({ description = optional(string), ip_ranges = optional(set(string), []), ca_ids = optional(set(string), []), ca_keys = optional(set(string), []), cns = optional(set(string), []) }))`, `default = {}`. `map(object)` over `list(object)` for stable addressing (repo rule).
- `cas`: `map(object({ ca_pem = string, description = optional(string) }))`, `default = {}`.
- Toggles `create_api_access_policy`, `create_api_access_rules`, `create_cas`, `bool`, default `true`. Naming: `terraform-variables` prefers `enable_`/`is_`, but the repository convention (`openspec/config.yaml` and the five existing `create_*`) is `create_`; the existing pattern wins for consistency, and there is no `# DEVIATION` because `config.yaml` explicitly allows `create_`. Default `true` is safe because the inputs default to empty, so nothing is created and existing users see no diff.
- Alternative rejected: `count` for the policy (repo rule: `for_each`); a plain `object` needs a one-key map internally: `local.api_access_policies = var.create_api_access_policy && var.api_access_policy != null ? { this = var.api_access_policy } : {}`, so the resource address is `outscale_api_access_policy.this["this"]`.

### 2. The policy is an account-wide singleton with a no-op destroy

The Outscale account has exactly one API access policy; the "resource" is an update of that single setting (create calls the update API; the provider's `Delete` does nothing). Consequences, all to be documented in `SECURITY.md`, the variable description and the README:
- `tofu destroy`, or changing `api_access_policy` to `null`, **removes the object from state only**; the cap and trusted session stay active.
- To disable: apply `{ max_access_key_expiration_seconds = 0, require_trusted_env = false }` (docs "Deactivate a trusted session"), then remove the input.
- Two stacks managing the same account would fight over it; the module must be instantiated once per account for this input. No import needed: create is idempotent and adopts the current server value on first apply (plan shows the diff to the desired values).
- No `lifecycle { prevent_destroy }`: since destroy is already a no-op, it would only block unrelated destroys.

### 3. Lock-out risk and guardrails (validation vs `check`)

Rule of `terraform-security`: `validation` when the input is never acceptable, `check` for dangerous but legal setups.

`validation` on `api_access_policy` (never acceptable; provider facts):
1. `max_access_key_expiration_seconds` integer in `[0, 3153600000]` (`floor(x) == x`); message names the range.
2. `require_trusted_env` implies `max_access_key_expiration_seconds > 0` (provider `ValidateConfig` rejects it at plan anyway; the module rejects earlier with a named message and a unit test that needs no provider).
3. `require_trusted_env_secure_mode == true` implies `require_trusted_env == true` (documented prerequisite; the provider does not check it, so the API would reject at apply or silently ignore it).

`check` blocks (warnings; module-visible inputs only, cannot see unmanaged keys/rules):
- `api_access_trusted_env_rules_have_ca`: if the policy is on and `require_trusted_env`, every managed rule must have `length(ca_ids) + length(ca_keys) > 0` (docs: "Specify a CA in all your API access rules" before activating a trusted session). Warning names offending rule keys.
- `api_access_expiry_cap_keys_have_expiration`: if the policy is on and `max_access_key_expiration_seconds > 0`, every module-managed `access_keys` entry must set `expiration_date` (docs: "all your access keys must have an expiration date"; also "the value must be greater than the remaining lifetime of each access key", which the module cannot compute because keys may be unmanaged; documented).

Lock-out scenarios (documented in `SECURITY.md`, not detectable by the module):
- Expiry cap while an existing unmanaged key has no expiry or a longer remaining life: the API rejects the update (apply error, no lock-out) or invalidates later use.
- Trusted session: users must use trusted access keys and log in to Cockpit v2 with MFA; keys/CLI flows that do not meet this are refused. Applying it with the key Terraform itself uses may cut the pipeline off. Mitigation: apply the policy in a separate, last stack run with a trusted key; keep a break-glass key/session.
- IP-restricting rules: after rules are applied, calls from addresses outside every rule are refused, including Terraform's own. The module cannot know the runner's egress IP. Mitigation: include the CI/operator CIDRs in the first rule, apply rules in a run whose source IP is already covered, keep a documented out-of-band path.
- Recovery: Outscale documents `UpdateApiAccessPolicy` with login/password authentication (`oapi-cli --login --password`). Whether password-authenticated calls bypass API access rules is **not verified offline**; task 7.3 records the verified recovery path, or the contact route to Outscale support, in `SECURITY.md` before release. Until verified, `SECURITY.md` must state "recovery path unverified" rather than claim one.

Considered and rejected: a variable carrying the caller's egress IP to prove coverage (extra input, cannot be trusted behind NAT/proxy); `precondition` on the policy resource (fails apply for combinations that are legal for unmanaged keys/rules).

### 4. Dependency graph and ordering

```
outscale_ca.this[k] ──> outscale_api_access_rule.this[r] ──┐
outscale_access_key.this[a] (existing, expiry) ────────────┼──> outscale_api_access_policy.this["this"]
outscale_user.this ──> outscale_access_key.this            ┘
```

- Rule -> CA: implicit through `ca_keys` -> `outscale_ca.this[key].ca_id`; destroy order is the reverse, so a CA is deleted after the rules that reference it (the API refuses deleting a referenced CA).
- Policy -> rules and access keys: explicit `depends_on = [outscale_api_access_rule.this, outscale_access_key.this]` (no attribute reference exists, and the trusted session requires CAs on rules and expiry on keys to already be in place). This is the "depends_on only when implicit dependencies are insufficient" case.

### 5. Perpetual-diff avoidance

- `ip_ranges`, `ca_ids`, `cns`: provider type is `set(string)`; module type is `set(string)` -> order never matters. Merging `ca_ids` with `ca_keys`: `toset(concat(tolist(ca_ids), [for k in ca_keys : outscale_ca.this[k].ca_id]))`.
- Optional + Computed arguments: send `null` when the module value is empty (`length(x) > 0 ? x : null`). A `null` config on a Computed attribute keeps the server value, so there is no diff; sending `[]` could differ from what the server returns. Consequence (documented limitation, provider behaviour): removing all entries of a set in configuration does **not** clear it on the server; to change, replace with a different value, or recreate the rule (remove then re-add the map key in two applies).
- IP form: only canonical CIDR accepted (`can(cidrhost(x, 0)) && cidrsubnet(x, 0, 0) == x`, which works for IPv4 and IPv6). The provider accepts bare IPs and the docs show `"192.0.2.0"`, but whether the API echoes it as `192.0.2.0/32` is unverified offline; accepting only the form the server reads back removes the risk (repo rule "send values in the form the server reads back"). Whether the API accepts IPv6 at all is unverified; task 8.3 confirms it against the API or restricts the validation to IPv4.
- `description`: Optional + Computed; sent only when not `null`.
- `require_trusted_env_secure_mode`: Optional + Computed default `false`; sent as `null` when unset, so the provider default is applied and read back identical.
- `ca_pem`: `RequiresReplace`; the PEM is stored as configured and not read back. Trailing newline differences between files are a caller concern; the example reads the file with `file()` unchanged. The integration run (task 8.3) must show an empty second plan.

### 6. Secrets and state (`terraform-security`)

- `ca_pem` is a **public** CA certificate (the issuer's certificate that API access rules use to verify client certificates); the private key stays with the CA owner and never reaches the module. It is therefore not sensitive and is not `ephemeral`, there is no `*_wo` argument for it in the provider, and `terraform-security` "Keep secret material out of state" does not apply to it. Hiding public certificates would only hinder review of plans. The safeguard instead is validation rejecting `PRIVATE KEY` markers so a private key can never be passed by mistake (a private key pasted there would land in state, plan output and CI logs).
- No new secret is created or output; `api_access_policy`, rules and CAs hold no credentials. `SECURITY.md` "what lands in state" gains: CA PEM (public), rule IP ranges (network topology: treat the state as internal), policy values.
- Least privilege: the identity running Terraform needs the EIM/API permissions for `ReadApiAccessPolicy`/`UpdateApiAccessPolicy`, `*ApiAccessRule*` and `*Ca*` actions only when these inputs are used; `SECURITY.md` lists them under the least-privilege section (`terraform-security` "Least privilege"). The exact Outscale action names are confirmed from the API reference in task 7.2.
- No control weakened (`quality-security` "No silent weakening"): the change only adds controls and opt-in; the provider floor is raised for a feature, not to relax a constraint.

### 7. Versioning (`terraform-versioning`, `terraform-providers`)

Provider floor `~> 1.8` -> `~> 1.9` to use `require_trusted_env_secure_mode` (introduced in v1.9.0): **MAJOR**, v1.1.0 -> v2.0.0, no deviation recorded; migration/rollback in `proposal.md`. README compatibility table and requirements row updated (`terraform-versioning` "Breaking change checklist": update `SECURITY.md` and README compatibility tables; no input/output is removed or renamed, so no deprecation or `moved` block). The commit subject must read as the CHANGELOG line and carry the major marker, for example: `Add API access policy, rules and CA management (requires provider ~> 1.9, major)`. The alternative (MINOR, keep `~> 1.8`) is recorded in `proposal.md` as rejected by the maintainer.

### 8. Variable definitions (final shape, with validation)

```hcl
variable "api_access_policy" {
  description = "Account-wide API access policy (singleton). null leaves the policy untouched. WARNING: removing it later does not reset the server-side policy; set max_access_key_expiration_seconds = 0 and require_trusted_env = false first."
  type = object({
    max_access_key_expiration_seconds = number
    require_trusted_env               = bool
    require_trusted_env_secure_mode   = optional(bool)
  })
  default = null

  validation { # range + integer, null-safe
    condition     = var.api_access_policy == null ? true : (floor(var.api_access_policy.max_access_key_expiration_seconds) == var.api_access_policy.max_access_key_expiration_seconds && var.api_access_policy.max_access_key_expiration_seconds >= 0 && var.api_access_policy.max_access_key_expiration_seconds <= 3153600000)
    error_message = "max_access_key_expiration_seconds must be an integer between 0 and 3153600000 inclusive."
  }
  validation { # trusted env needs a cap
    condition     = var.api_access_policy == null ? true : (!var.api_access_policy.require_trusted_env || var.api_access_policy.max_access_key_expiration_seconds > 0)
    error_message = "require_trusted_env = true requires max_access_key_expiration_seconds greater than 0."
  }
  validation { # secure mode needs trusted env
    condition     = var.api_access_policy == null ? true : (!coalesce(var.api_access_policy.require_trusted_env_secure_mode, false) || var.api_access_policy.require_trusted_env)
    error_message = "require_trusted_env_secure_mode = true requires require_trusted_env = true."
  }
}
```

`api_access_rules` validations (each `alltrue` over entries, message names the offending key where possible): has `ip_ranges` or CA; `cns` implies CA; canonical CIDR; `ca_keys` subset of `keys(var.cas)` (cross-variable reference, allowed since Terraform/OpenTofu 1.9, below the `>= 1.10.0` floor); `ca_ids` start with `ca-`. `cas` validations: `can(regex("-----BEGIN CERTIFICATE-----", ca_pem))` and `!can(regex("PRIVATE KEY", ca_pem))`.

Variable order in `variables.tf`: the new variables follow the existing "Conditional Creation Variables" section (toggles) and then one section per input; all have defaults, so no required-variable ordering issue.

### 9. Outputs (none sensitive)

| Output | Value | Empty when |
|---|---|---|
| `api_access_policy` | map keyed `this`: `max_access_key_expiration_seconds`, `require_trusted_env`, `require_trusted_env_secure_mode` | not created: `{}` |
| `api_access_rules` | map: `api_access_rule_id`, `ip_ranges`, `ca_ids`, `cns`, `description` | `{}` |
| `api_access_rule_ids` | key -> `api_access_rule_id` | `{}` |
| `cas` | map: `ca_id`, `ca_fingerprint`, `description` | `{}` |
| `ca_ids` | key -> `ca_id` | `{}` |

Computed vs configurable: IDs/fingerprint/`request_id` computed; `request_id` is not exported (noise). Outputs follow the existing `for k, v in resource.this` style, which yields `{}` when nothing is created. No secrets, no `sensitive = true` needed; the `access_keys` output stays sensitive and unchanged.

### 10. Files to create or modify

| File | Purpose |
|---|---|
| `versions.tf` | provider `~> 1.9` |
| `variables.tf` | 3 toggles, `api_access_policy`, `api_access_rules`, `cas` + validations |
| `main.tf` | `outscale_ca.this`, `outscale_api_access_rule.this`, `outscale_api_access_policy.this`, `local` for the singleton and CA-id merge, 2 `check` blocks (a `locals`-only block may be placed in `main.tf`; no new empty file) |
| `outputs.tf` | 5 outputs |
| `tests/main.tftest.hcl` (new) | plan-mode tests with `mock_provider "outscale" {}` (`terraform-testing`) |
| `examples/complete/main.tf`, `variables.tf` (if needed), `outputs.tf`, `versions.tf` | policy/rules/CA demo, restrictive and safe, with a CA PEM file under `examples/complete/ca/` using a throw-away public test certificate |
| `examples/minimal/versions.tf` | provider `~> 1.9` |
| `README.md` | features, requirements row, usage snippet, limitations, compat table (outside `BEGIN_TF_DOCS`/`END_TF_DOCS` and the generated tables; regenerated parts via terraform-docs) |
| `SECURITY.md` | lock-out, recovery, no-op destroy, public CA, least-privilege actions, state table |
| `TESTING.md` | `tofu test`, new validation cases |
| `CHANGELOG.md` | not edited by hand (git-cliff generates it from commit subjects) |
| `openspec/specs/api-access/spec.md` | created at archive from this change's delta |

## Risks / Trade-offs

- [Lock-out of the Terraform identity by rules or trusted session] -> opt-in only; `check` warnings; apply order and break-glass guidance in `SECURITY.md`; recovery path verified in task 7.3 or explicitly marked unverified.
- [Account-wide singleton fought over by two stacks] -> documented single owner; no import needed.
- [Destroy does not disable the policy] -> documented, spec scenario, variable description; explicit disable procedure.
- [Optional+Computed sets cannot be cleared by omission] -> documented limitation; replace values or recreate the key.
- [Bare IP / IPv6 normalisation by the API unverified offline] -> canonical-CIDR-only validation; integration second-plan-empty check (task 8.3).
- [`check` blocks only see module-managed keys/rules] -> warnings worded accordingly; guidance covers unmanaged ones.
- [Provider floor forces upgrade] -> MAJOR release with migration note; alternative in `proposal.md`.
- [`require_trusted_env_secure_mode` API behaviour beyond docs (restricted CLI calls)] -> out of module control; documented as risk in `SECURITY.md`.

## Migration Plan

1. Consumers on provider 1.8.x: `tofu init -upgrade` after changing the module ref to v2.0.0 (provider -> 1.9.x); plan must be empty with no new input set.
2. Adoption of new inputs: apply in order CAs -> rules (with CI IP covered) -> policy, one change per apply, with a second console/session open.
3. Rollback: remove the new inputs (disabling the policy first, see Decision 2; rules and CAs delete normally), then pin the module to v1.1.0 and provider `~> 1.8`.

## Open Questions

- Resolved: the maintainer chose MAJOR (v2.0.0) with `~> 1.9` and `require_trusted_env_secure_mode`; the MINOR alternative in `proposal.md` is rejected.
- Whether password-authenticated `UpdateApiAccessPolicy` bypasses API access rules (recovery path) and whether the API normalises bare IPs/IPv6: answered by tasks 8.3 and 7.3 against a real account, not by this design.
