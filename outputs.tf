################################################################################
# User Outputs
################################################################################

output "users" {
  description = "Map of created EIM users with their attributes"
  value = {
    for k, v in outscale_user.this : k => {
      user_id       = v.user_id
      user_name     = v.user_name
      user_email    = v.user_email
      path          = v.path
      creation_date = v.creation_date
    }
  }
}

output "user_ids" {
  description = "Map of user keys to user IDs"
  value       = { for k, v in outscale_user.this : k => v.user_id }
}

output "user_names" {
  description = "Map of user keys to user names"
  value       = { for k, v in outscale_user.this : k => v.user_name }
}

################################################################################
# Group Outputs
################################################################################

output "groups" {
  description = "Map of created user groups with their attributes"
  value = {
    for k, v in outscale_user_group.this : k => {
      user_group_id   = v.user_group_id
      user_group_name = v.user_group_name
      orn             = v.orn
      path            = v.path
      creation_date   = v.creation_date
    }
  }
}

output "group_orns" {
  description = "Map of group keys to group ORNs"
  value       = { for k, v in outscale_user_group.this : k => v.orn }
}

################################################################################
# Policy Outputs
################################################################################

output "policies" {
  description = "Map of created policies with their attributes"
  value = {
    for k, v in outscale_policy.this : k => {
      policy_id                 = v.policy_id
      policy_name               = v.policy_name
      orn                       = v.orn
      policy_default_version_id = v.policy_default_version_id
      path                      = v.path
      description               = v.description
      is_linkable               = v.is_linkable
      resources_count           = v.resources_count
      creation_date             = v.creation_date
    }
  }
}

output "policy_orns" {
  description = "Map of policy keys to policy ORNs"
  value       = { for k, v in outscale_policy.this : k => v.orn }
}

################################################################################
# Policy Version Outputs
################################################################################

output "policy_versions" {
  description = "Map of created policy versions with their attributes"
  value = {
    for k, v in outscale_policy_version.this : k => {
      version_id      = v.version_id
      creation_date   = v.creation_date
      default_version = v.default_version
    }
  }
}

################################################################################
# Access Key Outputs
################################################################################

output "access_keys" {
  description = "Map of created access keys with their attributes (sensitive)"
  value = {
    for k, v in outscale_access_key.this : k => {
      access_key_id   = v.access_key_id
      secret_key      = v.secret_key
      state           = v.state
      expiration_date = v.expiration_date
      creation_date   = v.creation_date
    }
  }
  sensitive = true
}

output "access_key_ids" {
  description = "Map of access key keys to access key IDs (non-sensitive)"
  value       = { for k, v in outscale_access_key.this : k => v.access_key_id }
}
