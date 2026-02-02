# Outscale IAM Terraform Module

[![Apache 2.0][apache-shield]][apache]
[![Terraform][terraform-badge]][terraform-url]
[![Outscale Provider][outscale-badge]][outscale-url]
[![Latest Release][release-badge]][release-url]

A production-ready Terraform module for creating and managing **Outscale EIM (External Identity Management)** resources including users, groups, policies, and access keys.

## Features

- **EIM Users**: Create and manage users with configurable paths, emails, and policy attachments
- **User Groups**: Organize users into groups with shared permissions
- **Managed Policies**: Create custom policies with JSON documents and versioning support
- **Policy Versions**: Manage multiple versions of policies with default selection
- **Access Keys**: Create access keys with state management and expiration dates
- **Conditional Creation**: Toggle resource creation with boolean flags
- **Map-based Resources**: Use meaningful keys for easy reference and stable state management

## Requirements

| Name | Version |
|------|---------|
| [terraform](#requirement\_terraform) | >= 1.10.0 |
| [outscale](#requirement\_outscale) | ~> 1.3 |

## Usage

### Basic Example

```hcl
module "iam" {
  source = "path/to/outscale-iam"

  # Create a simple user
  users = {
    developer = {
      user_name  = "developer-1"
      user_email = "dev@example.com"
      path       = "/developers/"
    }
  }

  # Create a group and add the user
  groups = {
    developers = {
      user_group_name = "developers"
      path            = "/developers/"
      users = [
        {
          user_name = "developer-1"
          path      = "/developers/"
        }
      ]
    }
  }
}
```

### Complete Example with Policies

```hcl
module "iam" {
  source = "path/to/outscale-iam"

  # Create managed policies
  policies = {
    admin = {
      policy_name = "admin-policy"
      document    = file("policies/admin.json")
      description = "Full administrative access"
      path        = "/admin/"
    }
    readonly = {
      policy_name = "readonly-policy"
      document    = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Effect   = "Allow"
            Action   = ["eim:Get*", "eim:List*", "fcu:Describe*"]
            Resource = "*"
          }
        ]
      })
      description = "Read-only access"
    }
  }

  # Create users with policy attachments
  users = {
    admin = {
      user_name  = "admin-user"
      user_email = "admin@example.com"
      path       = "/admin/"
      policies = [
        {
          policy_orn = "orn:ows:idauth::ACCOUNT_ID:policy/admin/admin-policy"
        }
      ]
    }
  }

  # Create groups with users and policies
  groups = {
    admins = {
      user_group_name = "admins"
      path            = "/admin/"
      users = [
        { user_name = "admin-user", path = "/admin/" }
      ]
      policies = [
        { policy_orn = "orn:ows:idauth::ACCOUNT_ID:policy/admin/admin-policy" }
      ]
    }
  }

  # Create access keys
  access_keys = {
    admin_key = {
      user_name       = "admin-user"
      state           = "ACTIVE"
      expiration_date = "2027-01-01"
    }
  }
}
```

### Conditional Creation

```hcl
module "iam" {
  source = "path/to/outscale-iam"

  # Disable specific resource types
  create_users       = true
  create_groups      = true
  create_policies    = true
  create_access_keys = false  # Don't create access keys

  users = {
    # ...
  }
}
```

## Security Considerations

> **For comprehensive security guidance, see [SECURITY.md](SECURITY.md).**

1. **Secret Keys in State**: Access key secrets are stored in Terraform state. Always use encrypted state backends (e.g., S3 with SSE).

2. **State File Security**: Treat your Terraform state file as sensitive. Restrict access and enable encryption at rest.

3. **Access Key Rotation**: Set expiration dates on access keys and rotate them regularly. The `expiration_date` parameter helps enforce this.

4. **Least Privilege**: Design policies with minimal required permissions. The example policies demonstrate both permissive and restrictive patterns.

5. **Sensitive Outputs**: The `access_keys` output is marked as sensitive. Use `nonsensitive()` only when absolutely necessary.

## Known Limitations

1. **User ORN Not Available**: The Outscale provider's `outscale_user` resource does not export the user's ORN. If you need the user ORN for policy attachments, you must construct it manually:
   ```
   orn:ows:idauth::${account_id}:user${path}${user_name}
   ```

2. **No User Lookup by Name**: The `outscale_user` data source only supports lookup by `user_id`, not by `user_name`. Plan accordingly when referencing existing users.

3. **Policy Document Size**: Outscale has limits on policy document size. Very large policies may need to be split into multiple smaller policies.

4. **Access Key Limits**: Each user can have a maximum of 2 access keys. The module does not enforce this limit; Outscale API will reject additional keys.

5. **No Tags Support**: Outscale EIM resources (users, groups, policies, access keys) do not support tags at the API level. This is a provider/API limitation, not a module limitation. Unlike compute resources (VMs, volumes), IAM resources cannot be tagged.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.10.0 |
| <a name="requirement_outscale"></a> [outscale](#requirement\_outscale) | ~> 1.3 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_outscale"></a> [outscale](#provider\_outscale) | ~> 1.3 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [outscale_access_key.this](https://registry.terraform.io/providers/outscale/outscale/latest/docs/resources/access_key) | resource |
| [outscale_policy.this](https://registry.terraform.io/providers/outscale/outscale/latest/docs/resources/policy) | resource |
| [outscale_policy_version.this](https://registry.terraform.io/providers/outscale/outscale/latest/docs/resources/policy_version) | resource |
| [outscale_user.this](https://registry.terraform.io/providers/outscale/outscale/latest/docs/resources/user) | resource |
| [outscale_user_group.this](https://registry.terraform.io/providers/outscale/outscale/latest/docs/resources/user_group) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_access_keys"></a> [access\_keys](#input\_access\_keys) | Map of access keys to create. If user\_name is omitted, the key is created for the caller. | <pre>map(object({<br/>    user_name       = optional(string)<br/>    state           = optional(string, "ACTIVE")<br/>    expiration_date = optional(string)<br/>  }))</pre> | `{}` | no |
| <a name="input_create_access_keys"></a> [create\_access\_keys](#input\_create\_access\_keys) | Whether to create access keys | `bool` | `true` | no |
| <a name="input_create_groups"></a> [create\_groups](#input\_create\_groups) | Whether to create user groups | `bool` | `true` | no |
| <a name="input_create_policies"></a> [create\_policies](#input\_create\_policies) | Whether to create managed policies | `bool` | `true` | no |
| <a name="input_create_policy_versions"></a> [create\_policy\_versions](#input\_create\_policy\_versions) | Whether to create policy versions | `bool` | `true` | no |
| <a name="input_create_users"></a> [create\_users](#input\_create\_users) | Whether to create EIM users | `bool` | `true` | no |
| <a name="input_groups"></a> [groups](#input\_groups) | Map of user groups to create. Groups can contain users and have policies attached. | <pre>map(object({<br/>    user_group_name = string<br/>    path            = optional(string, "/")<br/>    users = optional(list(object({<br/>      user_name = string<br/>      path      = optional(string)<br/>    })), [])<br/>    policies = optional(list(object({<br/>      policy_orn         = string<br/>      default_version_id = optional(string)<br/>    })), [])<br/>  }))</pre> | `{}` | no |
| <a name="input_policies"></a> [policies](#input\_policies) | Map of managed policies to create. The document should be a valid JSON policy string. | <pre>map(object({<br/>    policy_name = string<br/>    document    = string<br/>    description = optional(string)<br/>    path        = optional(string, "/")<br/>  }))</pre> | `{}` | no |
| <a name="input_policy_versions"></a> [policy\_versions](#input\_policy\_versions) | Map of policy versions to create. Used to add additional versions to existing policies. | <pre>map(object({<br/>    policy_orn     = string<br/>    document       = string<br/>    set_as_default = optional(bool, false)<br/>  }))</pre> | `{}` | no |
| <a name="input_users"></a> [users](#input\_users) | Map of EIM users to create. Each user can have policies attached via the policies list. | <pre>map(object({<br/>    user_name  = string<br/>    user_email = optional(string)<br/>    path       = optional(string, "/")<br/>    policies = optional(list(object({<br/>      policy_orn         = string<br/>      default_version_id = optional(string)<br/>    })), [])<br/>  }))</pre> | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_access_key_ids"></a> [access\_key\_ids](#output\_access\_key\_ids) | Map of access key keys to access key IDs (non-sensitive) |
| <a name="output_access_keys"></a> [access\_keys](#output\_access\_keys) | Map of created access keys with their attributes (sensitive) |
| <a name="output_group_orns"></a> [group\_orns](#output\_group\_orns) | Map of group keys to group ORNs |
| <a name="output_groups"></a> [groups](#output\_groups) | Map of created user groups with their attributes |
| <a name="output_policies"></a> [policies](#output\_policies) | Map of created policies with their attributes |
| <a name="output_policy_orns"></a> [policy\_orns](#output\_policy\_orns) | Map of policy keys to policy ORNs |
| <a name="output_policy_versions"></a> [policy\_versions](#output\_policy\_versions) | Map of created policy versions with their attributes |
| <a name="output_user_ids"></a> [user\_ids](#output\_user\_ids) | Map of user keys to user IDs |
| <a name="output_user_names"></a> [user\_names](#output\_user\_names) | Map of user keys to user names |
| <a name="output_users"></a> [users](#output\_users) | Map of created EIM users with their attributes |
<!-- END_TF_DOCS -->

## Documentation

| Document | Description |
|----------|-------------|
| [README.md](README.md) | This file - module overview and usage |
| [SECURITY.md](SECURITY.md) | Security best practices and guidelines |
| [TESTING.md](TESTING.md) | Testing procedures and validation |
| [CHANGELOG.md](CHANGELOG.md) | Version history and release notes |

## Contributing

Contributions are welcome! Please ensure:

1. All changes pass `terraform fmt` and `terraform validate`
2. Update documentation for any new features or changes
3. Add examples for new functionality
4. Follow existing code style and conventions

## License

Licensed under the Apache License, Version 2.0. See [LICENSE](LICENSE) for full details.

Copyright 2026 - This module is independently maintained and not affiliated with Outscale.

## Disclaimer

This module is provided "as is" without warranty of any kind, express or implied. The authors and contributors are not responsible for any issues, damages, or losses arising from the use of this module. No official support is provided. Use at your own risk.

[apache]: https://opensource.org/licenses/Apache-2.0
[apache-shield]: https://img.shields.io/badge/License-Apache%202.0-blue.svg

[terraform-badge]: https://img.shields.io/badge/Terraform-%3E%3D1.10-623CE4
[terraform-url]: https://www.terraform.io

[outscale-badge]: https://img.shields.io/badge/outscale%20Provider-~%3E1.3-4f0599
[outscale-url]: https://registry.terraform.io/providers/outscale/outscale/

[release-badge]: https://img.shields.io/gitlab/v/release/leminnov/terraform/modules/outscale-iam?include_prereleases&sort=semver
[release-url]: https://gitlab.com/leminnov/terraform/modules/outscale-iam/-/releases
