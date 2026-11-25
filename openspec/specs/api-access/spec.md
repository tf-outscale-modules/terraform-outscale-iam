# api-access Specification

## Purpose
Defines how the Outscale IAM module manages account-level API access control: the API access policy, API access rules and client Certificate Authorities. Everything is opt-in so existing configurations are unaffected.

## Requirements

### Requirement: Opt-in creation

The module SHALL create no API access resource unless the caller sets the matching input (`api_access_policy`, `api_access_rules`, `cas`), and the `create_api_access_policy`, `create_api_access_rules` and `create_cas` toggles (default `true`) SHALL each disable their resource type when `false`. Existing configurations SHALL plan with no change after the provider floor is met.

#### Scenario: Defaults create nothing
- **WHEN** the module is planned with no value for `api_access_policy`, `api_access_rules` and `cas`
- **THEN** no `outscale_api_access_policy`, `outscale_api_access_rule` or `outscale_ca` resource is planned
- **AND** the outputs `api_access_policy`, `api_access_rules`, `api_access_rule_ids`, `cas` and `ca_ids` are empty maps

#### Scenario: Toggle disables a populated input
- **WHEN** `api_access_rules` has entries and `create_api_access_rules = false`
- **THEN** no `outscale_api_access_rule` is planned

#### Scenario: Existing user upgrades
- **WHEN** a configuration valid for the previous release is planned with the new module version and provider 1.9.x
- **THEN** the plan shows no change

### Requirement: API access policy

When `api_access_policy` is set (and `create_api_access_policy` is `true`) the module SHALL manage exactly one `outscale_api_access_policy`, sending `max_access_key_expiration_seconds` and `require_trusted_env` always and `require_trusted_env_secure_mode` only when not `null`.

#### Scenario: Cap access-key lifetime
- **GIVEN** `api_access_policy = { max_access_key_expiration_seconds = 31536000, require_trusted_env = false }`
- **WHEN** the module is planned
- **THEN** one policy is planned with those two values
- **AND** `require_trusted_env_secure_mode` is left to the provider default (`false`)

#### Scenario: Activate a trusted session
- **GIVEN** `require_trusted_env = true` and `max_access_key_expiration_seconds > 0`
- **WHEN** the module is planned
- **THEN** the policy is planned with `require_trusted_env = true`

#### Scenario: Secure mode
- **GIVEN** `require_trusted_env = true`, `require_trusted_env_secure_mode = true` and `max_access_key_expiration_seconds > 0`
- **WHEN** the module is planned
- **THEN** the policy is planned with `require_trusted_env_secure_mode = true`

> NOTE: `require_trusted_env_secure_mode` requires provider >= 1.9.0.

### Requirement: Policy input validation

The module SHALL reject at plan time any `api_access_policy` where `max_access_key_expiration_seconds` is not an integer between `0` and `3153600000` inclusive, where `require_trusted_env` is `true` with `max_access_key_expiration_seconds = 0`, or where `require_trusted_env_secure_mode` is `true` without `require_trusted_env = true`. Each error message SHALL name the accepted values.

#### Scenario: Out-of-range lifetime
- **WHEN** `max_access_key_expiration_seconds = 3153600001` (or `-1`, or `1.5`)
- **THEN** validation fails naming the range 0..3153600000

#### Scenario: Trusted session without expiry cap
- **WHEN** `require_trusted_env = true` and `max_access_key_expiration_seconds = 0`
- **THEN** validation fails stating the value must be greater than 0

#### Scenario: Secure mode without trusted session
- **WHEN** `require_trusted_env_secure_mode = true` and `require_trusted_env = false`
- **THEN** validation fails stating `require_trusted_env` must be true

### Requirement: Policy lock-out guardrails

The module SHALL emit plan-time `check` warnings (not errors) for configurations the API may reject or that can lock callers out: a trusted session while any managed API access rule has no Certificate Authority, and a non-zero access-key lifetime cap while any access key managed by the module has no `expiration_date`.

#### Scenario: Trusted session with a rule lacking a CA
- **GIVEN** `require_trusted_env = true` and a managed rule with empty `ca_ids` and `ca_keys`
- **WHEN** the module is planned
- **THEN** a warning names the rule key and states every rule needs a CA for a trusted session

#### Scenario: Cap with a non-expiring managed key
- **GIVEN** `max_access_key_expiration_seconds > 0` and `access_keys` containing an entry whose `expiration_date` is `null`
- **WHEN** the module is planned
- **THEN** a warning names the access key entry and states all keys must have an expiration date

#### Scenario: Safe combination
- **WHEN** neither condition holds
- **THEN** no warning is emitted

### Requirement: Policy ordering and persistence

The policy SHALL be applied after the managed API access rules and access keys it constrains. Removing `api_access_policy` (or `terraform destroy`) SHALL NOT be presented as disabling the policy: the provider does not reset the server-side policy, and documentation SHALL state how to disable it explicitly.

#### Scenario: Apply order
- **WHEN** rules, access keys and the policy are created in one apply
- **THEN** the rules and access keys are created before the policy

#### Scenario: Removal leaves the policy active
- **WHEN** `api_access_policy` is changed from set to `null`
- **THEN** the plan removes the resource from state only, and SECURITY.md documents applying `max_access_key_expiration_seconds = 0`, `require_trusted_env = false` first to disable it

> NOTE: provider v1.9.0 implements `Delete` of `outscale_api_access_policy` as a no-op.

### Requirement: API access rules

For each entry of `api_access_rules` (when `create_api_access_rules` is `true`) the module SHALL create one `outscale_api_access_rule` keyed by the map key, sending `ip_ranges`, `ca_ids`, `cns` and `description` only when non-empty. A rule's CA IDs SHALL be the union of its `ca_ids` and the IDs of the module-created CAs named in `ca_keys`.

#### Scenario: IP-only rule
- **GIVEN** a rule with `ip_ranges = ["192.0.2.0/24"]`
- **WHEN** the module is planned
- **THEN** one rule is planned with that range and no `ca_ids`/`cns`

#### Scenario: Rule using a module-created CA
- **GIVEN** `cas.corp` and a rule with `ca_keys = ["corp"]`
- **WHEN** the module is planned
- **THEN** the rule's `ca_ids` is the (unknown until apply) ID of `cas.corp`
- **AND** the CA is created before the rule

#### Scenario: Rule using an existing CA
- **WHEN** a rule sets `ca_ids = ["ca-12345678"]`
- **THEN** the rule is planned with that ID

#### Scenario: Second plan is empty
- **WHEN** a rule with several `ip_ranges` is applied and planned again
- **THEN** the plan is empty regardless of the order of the entries

### Requirement: Rule input validation

The module SHALL reject at plan time any API access rule that cannot be applied safely or whose values the server would not read back identically; each error message SHALL name the accepted form.

#### Scenario: Empty rule
- **WHEN** a rule has no `ip_ranges`, `ca_ids` or `ca_keys`
- **THEN** validation fails stating a rule needs at least one IP range or CA

#### Scenario: CN without CA
- **WHEN** a rule sets `cns = ["client.example.com"]` with no CA
- **THEN** validation fails stating `cns` requires a CA

#### Scenario: Non-canonical or bare IP
- **WHEN** `ip_ranges = ["192.0.2.7"]` or `["192.0.2.7/24"]`
- **THEN** validation fails naming the canonical CIDR form

#### Scenario: CA key while CA creation is disabled
- **WHEN** a rule sets `ca_keys = ["corp"]` and `create_cas = false`
- **THEN** validation fails stating `create_cas` must be true or `ca_ids` used instead, rather than an invalid-index error

#### Scenario: CA ID shape
- **WHEN** a `ca_ids` entry does not start with `ca-`
- **THEN** validation fails (no stricter pattern is assumed, as the provider documentation shows only that form)

#### Scenario: Canonical CIDR required
- **WHEN** an `ip_ranges` entry is not a CIDR whose address equals its network address
- **THEN** validation fails, so values match what the server reads back

#### Scenario: Unknown CA key
- **WHEN** `ca_keys = ["missing"]` and `cas` has no `missing` key
- **THEN** validation fails naming the unknown key

### Requirement: Certificate Authorities

For each entry of `cas` (when `create_cas` is `true`) the module SHALL create one `outscale_ca` from `ca_pem` and optional `description`. `ca_pem` is public certificate material and SHALL NOT be marked sensitive, but the module SHALL reject a value that is not a PEM certificate or that contains private-key markers.

#### Scenario: Create a CA
- **GIVEN** `cas.corp.ca_pem` containing a `-----BEGIN CERTIFICATE-----` block
- **WHEN** the module is planned
- **THEN** one CA is planned keyed `corp`

#### Scenario: Private key pasted by mistake
- **WHEN** `ca_pem` contains `PRIVATE KEY`
- **THEN** validation fails stating that only a public CA certificate is accepted

#### Scenario: Not a certificate
- **WHEN** `ca_pem` lacks `-----BEGIN CERTIFICATE-----`
- **THEN** validation fails stating the PEM format is required

> NOTE: changing `ca_pem` replaces the CA (provider `RequiresReplace`).

### Requirement: Outputs

The module SHALL export `api_access_policy` (map keyed `this`, attributes `max_access_key_expiration_seconds`, `require_trusted_env`, `require_trusted_env_secure_mode`), `api_access_rules` (map of `api_access_rule_id`, `ip_ranges`, `ca_ids`, `cns`, `description`), `api_access_rule_ids` (key to ID), `cas` (map of `ca_id`, `ca_fingerprint`, `description`) and `ca_ids` (key to ID). None SHALL be sensitive and each SHALL be an empty map when its resources are not created.

#### Scenario: Outputs with resources
- **WHEN** a CA, a rule and the policy are created
- **THEN** `ca_ids`, `api_access_rule_ids` and `api_access_policy` contain their entries
- **AND** none of the outputs is marked sensitive

#### Scenario: Outputs without resources
- **WHEN** nothing is created
- **THEN** each output is `{}`

### Requirement: Provider floor

`versions.tf` and both examples SHALL require `outscale/outscale` `~> 1.9`, and the README requirements and compatibility table SHALL state the floor and the reason (`require_trusted_env_secure_mode`).

#### Scenario: Provider constraint
- **WHEN** `versions.tf` is read
- **THEN** the outscale constraint is `~> 1.9` and `required_version` is unchanged

### Requirement: Security documentation

`SECURITY.md` SHALL describe the account-wide scope of the policy, the lock-out scenarios (expiry cap, trusted session, IP-restricting rules), the recovery path, the no-op destroy, and that `ca_pem` is public and therefore not sensitive state.

#### Scenario: Reviewer looks for lock-out guidance
- **WHEN** `SECURITY.md` is read
- **THEN** it lists the lock-out scenarios, the order to apply changes and how to disable the policy
