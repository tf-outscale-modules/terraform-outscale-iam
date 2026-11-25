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

  # API access control (account-wide, opt-in). WARNING: these settings can lock
  # callers out of the API. Review SECURITY.md ("API Access Control") first.

  # Public CA certificate (never a private key) used by rules to verify client certificates.
  cas = {
    corp = {
      ca_pem      = file("${path.module}/ca/example-ca.crt")
      description = "${var.environment} example client CA"
    }
  }

  api_access_rules = {
    # Replace the documentation range with the egress addresses Terraform and your operators use.
    office = {
      description = "${var.environment} trusted source networks"
      ip_ranges   = toset(var.api_access_ip_ranges)
    }
    mtls = {
      description = "${var.environment} client certificates"
      ca_keys     = ["corp"]
    }
  }

  # Cap access-key lifetime to 1 year. Not a trusted session, so rules need no CA.
  # Removing this block later does NOT reset the policy: first apply
  # max_access_key_expiration_seconds = 0 and require_trusted_env = false.
  api_access_policy = {
    max_access_key_expiration_seconds = 31536000
    require_trusted_env               = false
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

output "ca_ids" {
  description = "Certificate Authority IDs"
  value       = module.iam.ca_ids
}

output "api_access_rule_ids" {
  description = "API access rule IDs"
  value       = module.iam.api_access_rule_ids
}

output "api_access_policy" {
  description = "API access policy as applied"
  value       = module.iam.api_access_policy
}
