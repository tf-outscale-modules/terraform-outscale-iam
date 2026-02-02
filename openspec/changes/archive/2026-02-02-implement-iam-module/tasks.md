# Tasks

## 1. Provider Configuration

- [x] 1.1 Update `versions.tf` with outscale provider requirement (source: `outscale/outscale`)
- [x] 1.2 Add provider version constraint (`~> 1.3`)

## 2. Variables Definition

- [x] 2.1 Define `create_users` boolean variable
- [x] 2.2 Define `create_groups` boolean variable
- [x] 2.3 Define `create_policies` boolean variable
- [x] 2.4 Define `create_access_keys` boolean variable
- [x] 2.5 Define `users` map variable with validation
- [x] 2.6 Define `groups` map variable with validation
- [x] 2.7 Define `policies` map variable with validation
- [x] 2.8 Define `access_keys` map variable with validation
- [x] 2.9 Define `policy_versions` map variable (optional feature)

## 3. User Resources

- [x] 3.1 Implement `outscale_user` resource with `for_each`
- [x] 3.2 Add dynamic `policy` block for policy attachments
- [x] 3.3 Add conditional creation with `create_users`

## 4. Group Resources

- [x] 4.1 Implement `outscale_user_group` resource with `for_each`
- [x] 4.2 Add dynamic `user` block for membership
- [x] 4.3 Add dynamic `policy` block for policy attachments
- [x] 4.4 Add conditional creation with `create_groups`

## 5. Policy Resources

- [x] 5.1 Implement `outscale_policy` resource with `for_each`
- [x] 5.2 Handle policy document from variable or file
- [x] 5.3 Add conditional creation with `create_policies`

## 6. Policy Version Resources

- [x] 6.1 Implement `outscale_policy_version` resource with `for_each`
- [x] 6.2 Support `set_as_default` option
- [x] 6.3 Add dependency on parent policy

## 7. Access Key Resources

- [x] 7.1 Implement `outscale_access_key` resource with `for_each`
- [x] 7.2 Support optional `user_name` (for self or other user)
- [x] 7.3 Support `state` and `expiration_date`
- [x] 7.4 Add conditional creation with `create_access_keys`
- [x] 7.5 Add `depends_on = [outscale_user.this]` for internal user validation

## 8. Outputs

- [x] 8.1 Define `users` output (user_id, user_name, user_email, path, creation_date - NO orn)
- [x] 8.2 Define `groups` output (user_group_id, name, orn, path, creation_date)
- [x] 8.3 Define `policies` output (policy_id, policy_name, orn, policy_default_version_id, creation_date)
- [x] 8.4 Define `policy_versions` output (version_id, creation_date, default_version)
- [x] 8.5 Define `access_keys` output (marked sensitive: access_key_id, secret_key, state, expiration_date)
- [x] 8.6 Add helper outputs for common use cases (user_ids, policy_orns, group_orns)

## 9. Example Configuration

- [x] 9.1 Update `examples/complete/main.tf` with full usage example
- [x] 9.2 Update `examples/complete/variables.tf` with example values
- [x] 9.3 Update `examples/complete/versions.tf` with provider config
- [x] 9.4 Add example policy JSON files

## 10. Documentation

- [x] 10.1 Update `README.md` with module description
- [x] 10.2 Add usage examples to README
- [x] 10.3 Document all variables with descriptions
- [x] 10.4 Document all outputs with descriptions
- [x] 10.5 Add security considerations section
- [x] 10.6 Run terraform-docs to generate documentation
- [x] 10.7 Add requirements section (Terraform >= 1.10.0, provider ~> 1.3)

## 11. Validation

- [x] 11.1 Run `terraform fmt` to format all files
- [x] 11.2 Run `terraform validate` on root module
- [x] 11.3 Run `terraform validate` on example
- [x] 11.4 Run `tflint` if available
- [x] 11.5 Verify all outputs are accessible

## 12. Testing

- [x] 12.1 Create minimal test configuration
- [x] 12.2 Verify plan succeeds with empty inputs
- [x] 12.3 Verify plan succeeds with sample inputs
- [x] 12.4 Document manual testing steps
