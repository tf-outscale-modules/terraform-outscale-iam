# Delta for IAM

## ADDED Requirements

### Requirement: EIM User Management

The module SHALL support creating and managing EIM users with configurable attributes.

#### Scenario: Create basic user

- GIVEN a user configuration with `user_name`
- WHEN the module is applied
- THEN an EIM user is created with the specified name
- AND the user has a default path of "/"

#### Scenario: Create user with full attributes

- GIVEN a user configuration with `user_name`, `user_email`, and `path`
- WHEN the module is applied
- THEN an EIM user is created with all specified attributes
- AND the path begins and ends with "/"

#### Scenario: Attach policy to user

- GIVEN a user configuration with a `policy` block containing `policy_orn`
- WHEN the module is applied
- THEN the managed policy is attached to the user
- AND the specified `default_version_id` is used if provided

#### Scenario: Create multiple users

- GIVEN a map of user configurations
- WHEN the module is applied with `for_each`
- THEN all specified users are created
- AND each user has its own independent configuration

### Requirement: User Group Management

The module SHALL support creating and managing user groups with membership and policies.

#### Scenario: Create basic group

- GIVEN a group configuration with `user_group_name`
- WHEN the module is applied
- THEN a user group is created with the specified name
- AND the group has a default path of "/"

#### Scenario: Add users to group

- GIVEN a group configuration with a list of `user` blocks
- WHEN the module is applied
- THEN all specified users are added to the group
- AND users can be referenced by name

#### Scenario: Attach policy to group

- GIVEN a group configuration with a `policy` block
- WHEN the module is applied
- THEN the managed policy is attached to the group
- AND all users in the group inherit the policy permissions

#### Scenario: Create multiple groups

- GIVEN a map of group configurations
- WHEN the module is applied with `for_each`
- THEN all specified groups are created independently

### Requirement: Managed Policy Management

The module SHALL support creating managed policies with JSON documents.

#### Scenario: Create policy with document

- GIVEN a policy configuration with `policy_name` and `document`
- WHEN the module is applied
- THEN a managed policy is created
- AND the policy document is stored as the default version (V1)
- AND the policy ORN is generated

#### Scenario: Create policy with description

- GIVEN a policy configuration with `description`
- WHEN the module is applied
- THEN the policy is created with the description
- AND the description is between 0 and 1000 characters

#### Scenario: Policy document validation

- GIVEN a policy document exceeding 5120 non-whitespace characters
- WHEN the module is applied
- THEN the creation fails with a validation error

#### Scenario: Create multiple policies

- GIVEN a map of policy configurations
- WHEN the module is applied with `for_each`
- THEN all specified policies are created
- AND each policy has a unique ORN

### Requirement: Policy Version Management

The module SHALL support creating additional versions of managed policies.

#### Scenario: Create policy version

- GIVEN a policy ORN and a new document
- WHEN a policy version is created
- THEN a new version is added to the policy
- AND the version ID is incremented (V2, V3, etc.)

#### Scenario: Set version as default

- GIVEN a policy version with `set_as_default = true`
- WHEN the module is applied
- THEN the new version becomes the active default
- AND previous default is retained but inactive

#### Scenario: Version limit

- GIVEN a policy with 5 existing versions
- WHEN attempting to create a 6th version
- THEN the creation fails
- AND an error indicates maximum versions reached

### Requirement: Access Key Management

The module SHALL support creating access keys for users.

#### Scenario: Create access key for self

- GIVEN an access key configuration without `user_name`
- WHEN the module is applied
- THEN an access key is created for the caller
- AND both `access_key_id` and `secret_key` are returned

#### Scenario: Create access key for user

- GIVEN an access key configuration with `user_name`
- WHEN the module is applied
- THEN an access key is created for the specified user
- AND the user must exist before creation

#### Scenario: Set access key expiration

- GIVEN an access key configuration with `expiration_date`
- WHEN the module is applied
- THEN the access key is created with the expiration
- AND the format is ISO 8601 (YYYY-MM-DD)

#### Scenario: Set access key state

- GIVEN an access key configuration with `state`
- WHEN the module is applied
- THEN the access key is created with the specified state
- AND valid states are "ACTIVE" or "INACTIVE"

#### Scenario: Secret key security warning

- GIVEN an access key is created via Terraform
- WHEN the module is applied
- THEN the secret key is stored in Terraform state
- AND a security warning should be documented

### Requirement: Conditional Resource Creation

The module SHALL support conditional creation of all resources.

#### Scenario: Skip user creation

- GIVEN `create_users = false`
- WHEN the module is applied
- THEN no users are created
- AND user outputs are empty

#### Scenario: Skip group creation

- GIVEN `create_groups = false`
- WHEN the module is applied
- THEN no groups are created
- AND group outputs are empty

#### Scenario: Skip policy creation

- GIVEN `create_policies = false`
- WHEN the module is applied
- THEN no policies are created
- AND policy outputs are empty

### Requirement: Output Attributes

The module SHALL export all relevant resource attributes.

#### Scenario: User outputs

- GIVEN users are created
- WHEN the module completes
- THEN outputs include `user_id`, `user_name`, `creation_date`, `path`, and `orn`

#### Scenario: Group outputs

- GIVEN groups are created
- WHEN the module completes
- THEN outputs include `user_group_id`, `name`, `orn`, `path`, and `creation_date`

#### Scenario: Policy outputs

- GIVEN policies are created
- WHEN the module completes
- THEN outputs include `policy_id`, `policy_name`, `orn`, `default_version_id`, and `creation_date`

#### Scenario: Access key outputs

- GIVEN access keys are created
- WHEN the module completes
- THEN outputs include `access_key_id`, `state`, `expiration_date`, and `creation_date`
- AND `secret_key` is marked as sensitive

### Requirement: Input Validation

The module SHALL validate inputs according to Outscale API constraints.

#### Scenario: User name validation

- GIVEN a user_name with invalid characters
- WHEN the module is applied
- THEN validation fails
- AND error indicates valid characters: alphanumeric, +, =, ,, ., @, -, _

#### Scenario: Path validation

- GIVEN a path not starting and ending with "/"
- WHEN the module is applied
- THEN validation fails
- AND error indicates path must begin and end with "/"

#### Scenario: Policy document size validation

- GIVEN a policy document
- WHEN the document exceeds 5120 non-whitespace characters
- THEN validation fails before API call
