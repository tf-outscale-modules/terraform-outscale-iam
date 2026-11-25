################################################################################
# EIM Users
################################################################################

resource "outscale_user" "this" {
  for_each = var.create_users ? var.users : {}

  user_name  = each.value.user_name
  user_email = each.value.user_email
  path       = each.value.path

  dynamic "policy" {
    for_each = each.value.policies
    content {
      policy_orn         = policy.value.policy_orn
      default_version_id = policy.value.default_version_id
    }
  }
}

################################################################################
# User Groups
################################################################################

resource "outscale_user_group" "this" {
  for_each = var.create_groups ? var.groups : {}

  user_group_name = each.value.user_group_name
  path            = each.value.path

  dynamic "user" {
    for_each = each.value.users
    content {
      user_name = user.value.user_name
      path      = user.value.path
    }
  }

  dynamic "policy" {
    for_each = each.value.policies
    content {
      policy_orn         = policy.value.policy_orn
      default_version_id = policy.value.default_version_id
    }
  }
}

################################################################################
# Managed Policies
################################################################################

resource "outscale_policy" "this" {
  for_each = var.create_policies ? var.policies : {}

  policy_name = each.value.policy_name
  document    = each.value.document
  description = each.value.description
  path        = each.value.path
}

################################################################################
# Policy Versions
################################################################################

resource "outscale_policy_version" "this" {
  for_each = var.create_policy_versions ? var.policy_versions : {}

  policy_orn     = each.value.policy_orn
  document       = each.value.document
  set_as_default = each.value.set_as_default

  depends_on = [outscale_policy.this]
}

################################################################################
# Access Keys
################################################################################

resource "outscale_access_key" "this" {
  for_each = var.create_access_keys ? var.access_keys : {}

  user_name       = each.value.user_name
  state           = each.value.state
  expiration_date = each.value.expiration_date

  # Ensure internal users are created first
  depends_on = [outscale_user.this]
}

################################################################################
# Certificate Authorities
################################################################################

resource "outscale_ca" "this" {
  for_each = var.create_cas ? var.cas : {}

  ca_pem      = each.value.ca_pem
  description = each.value.description
}

################################################################################
# API Access Rules
################################################################################

resource "outscale_api_access_rule" "this" {
  for_each = var.create_api_access_rules ? var.api_access_rules : {}

  # Optional+Computed arguments: null keeps the server value, no perpetual diff.
  description = each.value.description
  ip_ranges   = length(each.value.ip_ranges) > 0 ? each.value.ip_ranges : null
  ca_ids      = length(local.api_access_rule_ca_ids[each.key]) > 0 ? local.api_access_rule_ca_ids[each.key] : null
  cns         = length(each.value.cns) > 0 ? each.value.cns : null
}

################################################################################
# API Access Policy (account-wide singleton; provider Delete is a no-op)
################################################################################

resource "outscale_api_access_policy" "this" {
  for_each = local.api_access_policies

  max_access_key_expiration_seconds = each.value.max_access_key_expiration_seconds
  require_trusted_env               = each.value.require_trusted_env
  require_trusted_env_secure_mode   = each.value.require_trusted_env_secure_mode

  # A trusted session needs CAs on rules and expiry on keys to exist first.
  depends_on = [outscale_api_access_rule.this, outscale_access_key.this]
}

################################################################################
# Guardrails
################################################################################

locals {
  api_access_policies = var.create_api_access_policy && var.api_access_policy != null ? { this = var.api_access_policy } : {}

  # CA IDs per rule: existing IDs plus IDs of module-created CAs named in ca_keys.
  api_access_rule_ca_ids = {
    for k, v in var.api_access_rules : k => toset(concat(
      tolist(v.ca_ids),
      [for ck in v.ca_keys : outscale_ca.this[ck].ca_id]
    ))
  }

  trusted_env_rules_without_ca = length(local.api_access_policies) == 0 ? [] : (
    local.api_access_policies["this"].require_trusted_env && var.create_api_access_rules ? sort([
      for k, v in var.api_access_rules : k if length(v.ca_ids) + length(v.ca_keys) == 0
    ]) : []
  )

  expiry_cap_keys_without_expiration = length(local.api_access_policies) == 0 ? [] : (
    local.api_access_policies["this"].max_access_key_expiration_seconds > 0 && var.create_access_keys ? sort([
      for k, v in var.access_keys : k if v.expiration_date == null
    ]) : []
  )
}

check "api_access_trusted_env_rules_have_ca" {
  assert {
    condition     = length(local.trusted_env_rules_without_ca) == 0
    error_message = "A trusted session needs a Certificate Authority on every API access rule; rules without one: ${join(", ", local.trusted_env_rules_without_ca)}. Unmanaged rules are not checked."
  }
}

check "api_access_expiry_cap_keys_have_expiration" {
  assert {
    condition     = length(local.expiry_cap_keys_without_expiration) == 0
    error_message = "With max_access_key_expiration_seconds > 0 every access key needs an expiration_date; keys without one: ${join(", ", local.expiry_cap_keys_without_expiration)}. Unmanaged keys are not checked."
  }
}
