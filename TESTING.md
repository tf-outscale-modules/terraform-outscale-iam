# Testing Guide

This document describes how to test the Outscale IAM Terraform module.

## Prerequisites

1. **Outscale Account**: You need access to an Outscale account
2. **Access Keys**: API credentials configured via environment variables:
   ```bash
   export OUTSCALE_ACCESSKEYID="your-access-key-id"
   export OUTSCALE_SECRETKEYID="your-secret-key-id"
   export OUTSCALE_REGION="eu-west-2"  # or your preferred region
   ```
3. **Terraform/OpenTofu**: Version >= 1.10.0

## Quick Validation (No Outscale Account Required)

These tests validate syntax and configuration without connecting to Outscale:

```bash
# From module root directory
cd /path/to/outscale-iam

# Format check
tofu fmt -check -recursive

# Initialize and validate root module
tofu init -backend=false
tofu validate

# Initialize and validate examples
cd examples/minimal
tofu init -backend=false
tofu validate

cd ../complete
tofu init -backend=false
tofu validate
```

## Test 1: Empty Inputs (Minimal Example)

Verifies the module works with no inputs (all defaults):

```bash
cd examples/minimal
tofu init
tofu plan
```

**Expected**: Plan shows 0 resources to create (empty maps).

## Test 2: Complete Example

Verifies all features work together:

```bash
cd examples/complete
tofu init
tofu plan -var="environment=test"
```

**Expected**: Plan shows resources for:
- 3 policies (admin, readonly, developer)
- 4 users (admin, developer1, developer2, readonly)
- 3 groups (admins, developers, readonly)
- 2 access keys (admin_key, developer1_key)

## Test 3: Apply and Destroy (Requires Outscale Account)

Full integration test:

```bash
cd examples/complete

# Create resources
tofu apply -var="environment=test-$(date +%s)"

# Verify outputs
tofu output users
tofu output groups
tofu output policies
tofu output access_key_ids

# Clean up
tofu destroy -var="environment=test-..."
```

## Test 4: Conditional Creation

Test toggling resource types:

```hcl
module "iam" {
  source = "../../"

  create_users       = false  # Skip users
  create_groups      = true
  create_policies    = true
  create_access_keys = false  # Skip access keys

  policies = {
    test = {
      policy_name = "test-policy"
      document    = jsonencode({
        Version = "2012-10-17"
        Statement = [{
          Effect   = "Allow"
          Action   = "eim:GetUser"
          Resource = "*"
        }]
      })
    }
  }

  groups = {
    test = {
      user_group_name = "test-group"
    }
  }
}
```

**Expected**: Only policies and groups are created.

## Test 5: Variable Validation

Test that invalid inputs are rejected:

```hcl
# Invalid user name (contains space)
users = {
  invalid = {
    user_name = "invalid user"  # Should fail validation
  }
}

# Invalid path (doesn't end with /)
users = {
  invalid = {
    user_name = "valid-user"
    path      = "/no-trailing-slash"  # Should fail validation
  }
}

# Invalid access key state
access_keys = {
  invalid = {
    state = "INVALID"  # Should fail validation
  }
}
```

**Expected**: `tofu plan` fails with validation error messages.

## Cleanup

Always destroy test resources when done:

```bash
tofu destroy
```

## Troubleshooting

### "Provider requires explicit configuration"

Set the required environment variables:
```bash
export OUTSCALE_ACCESSKEYID="..."
export OUTSCALE_SECRETKEYID="..."
export OUTSCALE_REGION="eu-west-2"
```

### "User not found" for access keys

Ensure the user exists before creating an access key for them. Either:
1. Create the user in the same module call
2. Reference an existing user by their exact name

### Policy attachment errors

Ensure the policy ORN is correct and the policy exists. ORN format:
```
orn:ows:idauth::ACCOUNT_ID:policy/PATH/POLICY_NAME
```
