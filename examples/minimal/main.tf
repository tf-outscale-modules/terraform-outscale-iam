################################################################################
# Minimal Example - Outscale IAM Module
# Demonstrates basic usage with minimal configuration
################################################################################

module "iam" {
  source = "../../"

  # Empty inputs - module should work with all defaults
  # This tests that all variables have sensible defaults
}

# Outputs to verify the module works with empty inputs
output "users" {
  description = "Should be empty map"
  value       = module.iam.users
}

output "groups" {
  description = "Should be empty map"
  value       = module.iam.groups
}

output "policies" {
  description = "Should be empty map"
  value       = module.iam.policies
}
