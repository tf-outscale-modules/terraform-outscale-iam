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
