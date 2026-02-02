################################################################################
# Complete Example - Outscale IAM Module
# Demonstrates all available features and configurations
################################################################################

module "iam" {
  source = "../../"

  # Policies - create managed policies first (they'll be referenced by users/groups)
  policies = {
    admin = {
      policy_name = "${var.environment}-admin-policy"
      document    = file("${path.module}/policies/admin-policy.json")
      description = "Full administrative access"
      path        = "/admin/"
    }
    readonly = {
      policy_name = "${var.environment}-readonly-policy"
      document    = file("${path.module}/policies/readonly-policy.json")
      description = "Read-only access to all resources"
      path        = "/readonly/"
    }
    developer = {
      policy_name = "${var.environment}-developer-policy"
      document    = file("${path.module}/policies/developer-policy.json")
      description = "Developer access - compute and storage, no IAM management"
      path        = "/developer/"
    }
  }

  # Users - create EIM users with optional policy attachments
  users = {
    admin_user = {
      user_name  = "${var.environment}-admin"
      user_email = "admin@example.com"
      path       = "/admin/"
      # Note: policies reference the ORN which will be created by the policies above
      # In practice, you might attach policies after creation or use depends_on
    }
    developer1 = {
      user_name  = "${var.environment}-developer-1"
      user_email = "dev1@example.com"
      path       = "/developers/"
    }
    developer2 = {
      user_name  = "${var.environment}-developer-2"
      user_email = "dev2@example.com"
      path       = "/developers/"
    }
    readonly_user = {
      user_name  = "${var.environment}-readonly"
      user_email = "readonly@example.com"
      path       = "/readonly/"
    }
  }

  # Groups - create user groups with membership and policies
  groups = {
    admins = {
      user_group_name = "${var.environment}-admins"
      path            = "/admin/"
      users = [
        {
          user_name = "${var.environment}-admin"
          path      = "/admin/"
        }
      ]
    }
    developers = {
      user_group_name = "${var.environment}-developers"
      path            = "/developers/"
      users = [
        {
          user_name = "${var.environment}-developer-1"
          path      = "/developers/"
        },
        {
          user_name = "${var.environment}-developer-2"
          path      = "/developers/"
        }
      ]
    }
    readonly = {
      user_group_name = "${var.environment}-readonly"
      path            = "/readonly/"
      users = [
        {
          user_name = "${var.environment}-readonly"
          path      = "/readonly/"
        }
      ]
    }
  }

  # Access Keys - create access keys for service accounts
  access_keys = {
    admin_key = {
      user_name       = "${var.environment}-admin"
      state           = "ACTIVE"
      expiration_date = "2027-01-01"
    }
    developer1_key = {
      user_name       = "${var.environment}-developer-1"
      state           = "ACTIVE"
      expiration_date = "2027-01-01"
    }
  }

  # Policy versions are optional - use when you need to update a policy
  # policy_versions = {
  #   admin_v2 = {
  #     policy_orn     = module.iam.policy_orns["admin"]
  #     document       = file("${path.module}/policies/admin-policy-v2.json")
  #     set_as_default = true
  #   }
  # }
}

################################################################################
# Outputs
################################################################################

output "users" {
  description = "Created users"
  value       = module.iam.users
}

output "user_ids" {
  description = "User IDs for reference"
  value       = module.iam.user_ids
}

output "groups" {
  description = "Created groups"
  value       = module.iam.groups
}

output "group_orns" {
  description = "Group ORNs for policy attachment"
  value       = module.iam.group_orns
}

output "policies" {
  description = "Created policies"
  value       = module.iam.policies
}

output "policy_orns" {
  description = "Policy ORNs for attachment to users/groups"
  value       = module.iam.policy_orns
}

output "access_keys" {
  description = "Created access keys (sensitive)"
  value       = module.iam.access_keys
  sensitive   = true
}

output "access_key_ids" {
  description = "Access key IDs (non-sensitive)"
  value       = module.iam.access_key_ids
}
