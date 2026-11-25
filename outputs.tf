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

################################################################################
# Certificate Authority Outputs
################################################################################

output "cas" {
  description = "Map of created Certificate Authorities with their attributes (public data)"
  value = {
    for k, v in outscale_ca.this : k => {
      ca_id          = v.ca_id
      ca_fingerprint = v.ca_fingerprint
      description    = v.description
    }
  }
}

output "ca_ids" {
  description = "Map of CA keys to CA IDs"
  value       = { for k, v in outscale_ca.this : k => v.ca_id }
}

################################################################################
# API Access Rule Outputs
################################################################################

output "api_access_rules" {
  description = "Map of created API access rules with their attributes"
  value = {
    for k, v in outscale_api_access_rule.this : k => {
      api_access_rule_id = v.api_access_rule_id
      ip_ranges          = v.ip_ranges
      ca_ids             = v.ca_ids
      cns                = v.cns
      description        = v.description
    }
  }
}

output "api_access_rule_ids" {
  description = "Map of API access rule keys to rule IDs"
  value       = { for k, v in outscale_api_access_rule.this : k => v.api_access_rule_id }
}

################################################################################
# API Access Policy Output
################################################################################

output "api_access_policy" {
  description = "API access policy as applied, keyed 'this'; empty map when the policy is not managed"
  value = {
    for k, v in outscale_api_access_policy.this : k => {
      max_access_key_expiration_seconds = v.max_access_key_expiration_seconds
      require_trusted_env               = v.require_trusted_env
      require_trusted_env_secure_mode   = v.require_trusted_env_secure_mode
    }
  }
}
