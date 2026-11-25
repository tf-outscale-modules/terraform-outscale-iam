# Proposal

## Why

The module manages who an Outscale account's identities are (users, groups, policies, access keys) but not **how the account's API may be reached**. Callers who want a hardened account (mandatory access-key expiry, trusted sessions, API calls restricted to known IP ranges or client certificates) must hand-write `outscale_api_access_policy`, `outscale_api_access_rule` and `outscale_ca` next to the module, outside its validation, tests and security guidance. These are the account-level controls that complement the EIM resources the module already creates, and the access-key expiry the module already supports (`access_keys.*.expiration_date`) is a prerequisite of the policy.

## What Changes

- Add three **opt-in** inputs; with none set, `tofu plan` on an existing configuration shows no change:
  - `api_access_policy` (single optional object, default `null`): wraps `outscale_api_access_policy` (`max_access_key_expiration_seconds`, `require_trusted_env`, `require_trusted_env_secure_mode`).
  - `api_access_rules` (map of objects, default `{}`): wraps `outscale_api_access_rule` (`description`, `ip_ranges`, `ca_ids`, `ca_keys`, `cns`).
  - `cas` (map of objects, default `{}`): wraps `outscale_ca` (`ca_pem`, `description`).
- Add `create_api_access_policy`, `create_api_access_rules`, `create_cas` toggles (default `true`, like the existing `create_*`; nothing is created while the matching input is empty).
- Add outputs `api_access_policy`, `api_access_rules`, `api_access_rule_ids`, `cas`, `ca_ids` (none sensitive).
- Add validation blocks (ranges, CIDR form, PEM shape, cross-reference between rules and CAs, policy combinations) and `check` blocks that warn on lock-out-prone combinations.
- Raise the provider pin from `~> 1.8` to `~> 1.9` in `versions.tf` and both examples, because `require_trusted_env_secure_mode` first exists in outscale/outscale v1.9.0.
- **BREAKING (provider floor)**: consumers locked on provider 1.8.x must upgrade the provider to >= 1.9.0 (see Breaking changes).
- Add `tests/main.tftest.hcl` (the repository has no `tests/` yet), update `examples/complete/`, README, `SECURITY.md`, `TESTING.md`.

## Capabilities

### New Capabilities
- `api-access`: account-level API access control: API access policy (access-key lifetime cap, trusted session), API access rules (IP ranges, CAs, CNs) and client Certificate Authorities, with their validation, guardrails, outputs and opt-in behaviour.

### Modified Capabilities
<!-- None: the existing `iam` requirements do not change; all new behaviour is additive. -->

## Impact

- Files: `versions.tf`, `variables.tf`, `main.tf`, `outputs.tf`, `README.md` (outside the terraform-docs markers and the generated tables), `SECURITY.md`, `TESTING.md`, `examples/complete/*`, `examples/minimal/versions.tf`, new `tests/main.tftest.hcl`. Full list in `design.md`.
- New resources: `outscale_ca.this`, `outscale_api_access_rule.this`, `outscale_api_access_policy.this`, all created only when the caller sets the matching input.
- Dependencies: provider outscale/outscale `~> 1.9` (latest v1.9.0, 2026-11-25).
- Official documentation (verified for v1.9.0 and against the provider source):
  - https://registry.terraform.io/providers/outscale/outscale/latest/docs/resources/api_access_policy
  - https://registry.terraform.io/providers/outscale/outscale/latest/docs/resources/api_access_rule
  - https://registry.terraform.io/providers/outscale/outscale/latest/docs/resources/ca
  - https://docs.outscale.com/en/userguide/About-Your-API-Access-Policy.html
  - https://docs.outscale.com/en/userguide/About-API-Access-Rules.html
- Standards applied: `terraform-versioning`, `terraform-providers`, `terraform-variables`, `terraform-security`, `terraform-testing`, `quality-security` (details in `design.md`).

### Breaking changes and release classification

`terraform-versioning` ("Semver classification") and `terraform-providers` ("Raised floor") classify a raised provider floor as a **MAJOR** bump, even when every new input is optional. This change therefore releases as **MAJOR: v1.1.0 -> v2.0.0**, and the CHANGELOG line must say so with the reason (`require_trusted_env_secure_mode` needs provider 1.9.0). Migration path: bump the provider constraint of the root module to `~> 1.9` (or let `tofu init -upgrade` select 1.9.x), keep every existing input unchanged; no state move, no `moved` block and no resource address change is needed, so the first plan after the upgrade is empty. Rollback: pin the module back to the v1.1.0 tag and the provider back to `~> 1.8`; resources created by the new inputs must first be removed from configuration (see the policy destroy caveat in `design.md`: removing the policy does **not** reset it on the server).

### Alternative considered and rejected: keep `~> 1.8`, defer `require_trusted_env_secure_mode`

Ship `api_access_policy` without `require_trusted_env_secure_mode`, `api_access_rule` and `ca` (all present in 1.8.0, schemas identical to 1.9.0 apart from that one attribute), keeping the pin at `~> 1.8`. Per `terraform-versioning` that is a **MINOR** release (v1.2.0): new optional inputs, new resources, new outputs, no floor change. Trade-off: callers cannot enable the secure mode of a trusted session from the module until a later major release raises the floor; they would need a hand-written resource that then conflicts with the module-managed singleton policy. **Decision (maintainer): rejected.** The module ships as a MAJOR release (v2.0.0) with the provider floor `~> 1.9` and `require_trusted_env_secure_mode`.

### Known limitations of the provider/API (stated upfront)

- `outscale_api_access_policy` describes one account-wide setting. Its provider `Delete` is a no-op (v1.9.0 `resource_api_access_policy.go`): `tofu destroy` or removing the input leaves the policy active on the server.
- `outscale_api_access_rule` `ip_ranges`, `ca_ids`, `cns` and `description` are `Optional` + `Computed`: omitting one keeps the server value instead of clearing it, and the provider only sends arguments that are set.
- `outscale_ca.ca_pem` forces replacement; a CA still referenced by a rule cannot be deleted by the API.
- 1.9.0 deprecated x509 **provider authentication**. That is unrelated: this module has no `provider {}` block, and `outscale_ca` registers Certificate Authorities used by API access rules to authenticate **API clients** (mutual TLS) on the account; it is not the provider's own credential.
- Not verifiable offline: whether bare IPs are normalised by the API (hence CIDR-only validation) and whether API calls with login/password are exempt from API access rules (hence the verification task for the recovery path).
