# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0] - 2026-02-02

### Added

- Initial release of the Outscale IAM Terraform module
- **EIM Users**: Create and manage users with configurable paths, emails, and policy attachments
  - Input validation for user names (1-64 chars, alphanumeric + special chars)
  - Input validation for paths (must begin and end with `/`)
- **User Groups**: Organize users into groups with shared permissions
  - Dynamic user membership via `user` blocks
  - Dynamic policy attachment via `policy` blocks
- **Managed Policies**: Create custom policies with JSON documents
  - Policy name validation (1-128 chars)
  - Support for policy descriptions
  - Automatic version V1 creation
- **Policy Versions**: Manage multiple versions of policies
  - Support for `set_as_default` to activate new versions
  - Dependency management on parent policy
- **Access Keys**: Create access keys with state management and expiration
  - Support for creating keys for self (caller) or specific users
  - State management (ACTIVE/INACTIVE)
  - Expiration date support (ISO 8601 format)
  - Sensitive output handling
- **Conditional Creation**: Toggle resource creation with boolean flags
  - `create_users`, `create_groups`, `create_policies`, `create_access_keys`, `create_policy_versions`
- **Map-based Resources**: Use meaningful keys for stable state management
- **Comprehensive Outputs**:
  - Full resource attributes for users, groups, policies, policy versions, access keys
  - Helper outputs: `user_ids`, `user_names`, `group_orns`, `policy_orns`, `access_key_ids`
  - Sensitive marking for `access_keys` output
- **Documentation**:
  - Complete README with usage examples
  - TESTING.md with validation and integration test procedures
  - SECURITY.md with production security guidelines
- **Examples**:
  - `examples/complete/` - Full-featured example with all resource types
  - `examples/minimal/` - Minimal example with empty inputs

### Security

- Access key secret keys are marked as sensitive in outputs
- Documentation includes state file encryption recommendations
- Input validation prevents common misconfigurations

### Dependencies

- Terraform >= 1.10.0
- Outscale Provider ~> 1.3

[Unreleased]: https://gitlab.com/leminnov/terraform/modules/outscale-iam/-/compare/v1.0.0...HEAD
[1.0.0]: https://gitlab.com/leminnov/terraform/modules/outscale-iam/-/releases/v1.0.0
