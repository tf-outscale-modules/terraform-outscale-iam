# Proposal: Implement Outscale IAM Module

## Intent

Create a production-ready Terraform module for managing Outscale IAM (EIM - External Identity Management) resources. This module will provide a standardized, reusable way to provision and manage IAM users, groups, policies, and access keys on the Outscale cloud platform.

## Problem Statement

Currently, the module is a skeleton with no actual implementation. Organizations using Outscale need a consistent, well-documented approach to:
- Create and manage EIM users with proper paths and email addresses
- Organize users into groups with appropriate permissions
- Define and attach managed policies with versioning support
- Manage access keys with expiration dates for security compliance

## Scope

### In Scope

- **EIM Users**: Create users with configurable paths, emails, and policy attachments
- **User Groups**: Create groups with user membership and policy attachments
- **Managed Policies**: Create policies with JSON documents and version management
- **Access Keys**: Create access keys with state and expiration management
- **Policy Attachments**: Link policies to users and groups
- **Comprehensive Outputs**: Export all relevant resource attributes
- **Examples**: Provide complete usage examples

### Out of Scope

- Inline policies (use managed policies instead)
- Server certificates management
- API access rules
- Certificate authorities (CA)
- Cross-account IAM operations

## Approach

1. **Modular Design**: Use Terraform `for_each` to allow creating multiple resources from maps/lists
2. **Sensible Defaults**: Provide reasonable defaults while allowing full customization
3. **Conditional Creation**: Support `create` flags to optionally skip resource creation
4. **Output Everything**: Export all attributes needed for dependent resources
5. **Documentation**: Include terraform-docs compatible descriptions and examples

## Success Criteria

- [ ] All Terraform resources validate without errors
- [ ] Module can create users with attached policies
- [ ] Module can create groups with users and policies
- [ ] Module can create managed policies with versions
- [ ] Module can create access keys for users
- [ ] Example configurations work end-to-end
- [ ] README documentation is complete and accurate

## References

- [Outscale EIM Users Documentation](https://docs.outscale.com/en/userguide/About-EIM-Users.html)
- [Outscale EIM Groups Documentation](https://docs.outscale.com/en/userguide/About-EIM-Groups.html)
- [Outscale Policies Documentation](https://docs.outscale.com/en/userguide/About-Policies.html)
- [Outscale Access Keys Documentation](https://docs.outscale.com/en/userguide/About-Access-Keys.html)
- [Terraform Provider Outscale](https://registry.terraform.io/providers/outscale/outscale/latest/docs)
