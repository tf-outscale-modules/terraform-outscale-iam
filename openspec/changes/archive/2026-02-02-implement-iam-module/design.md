# Design: Outscale IAM Module

## Technical Approach

This Terraform module follows a **resource-centric design** where each IAM resource type (users, groups, policies, access keys) is managed through dedicated variable maps. The module uses `for_each` extensively to allow creating multiple resources of each type from a single module call.

## Provider Requirements

- **Provider**: `outscale/outscale` version `~> 1.3`
- **Terraform**: `>= 1.10.0`

```hcl
terraform {
  required_version = ">= 1.10.0"
  required_providers {
    outscale = {
      source  = "outscale/outscale"
      version = "~> 1.3"
    }
  }
}
```

## Architecture Decisions

### Decision: Map-based Resource Definition

Using maps with `for_each` instead of lists because:
- Resources can be referenced by meaningful keys (e.g., `module.iam.users["admin"]`)
- Adding/removing resources doesn't cause index shifts
- Clear ownership and naming in state file
- Supports conditional creation per resource

```hcl
# Example usage
users = {
  admin = {
    user_name  = "admin-user"
    user_email = "admin@example.com"
    path       = "/admin/"
  }
  service = {
    user_name = "service-account"
    path      = "/services/"
  }
}
```

### Decision: Nested Policy Attachment

Policies are attached within the user/group resource definition rather than as separate resources because:
- Outscale provider supports inline `policy` blocks
- Reduces resource count and complexity
- Keeps user/group definition self-contained
- Easier to understand relationships

```hcl
resource "outscale_user" "this" {
  for_each   = var.users
  user_name  = each.value.user_name

  dynamic "policy" {
    for_each = lookup(each.value, "policies", [])
    content {
      policy_orn         = policy.value.policy_orn
      default_version_id = lookup(policy.value, "default_version_id", null)
    }
  }
}
```

### Decision: Conditional Creation with Count

Using top-level `create_*` booleans with conditional expressions because:
- Simple on/off toggle for each resource type
- Allows importing existing resources without recreation
- Standard Terraform pattern

```hcl
variable "create_users" {
  type    = bool
  default = true
}

resource "outscale_user" "this" {
  for_each = var.create_users ? var.users : {}
  # ...
}
```

### Decision: Sensitive Output Handling

Marking secret keys as sensitive because:
- Prevents accidental exposure in logs
- Terraform enforces this at the state level
- Still accessible for automation via `nonsensitive()` if needed

```hcl
output "access_keys" {
  value = {
    for k, v in outscale_access_key.this : k => {
      access_key_id = v.access_key_id
      secret_key    = v.secret_key  # Marked sensitive at resource level
    }
  }
  sensitive = true
}
```

## Module Structure

```
outscale-iam/
├── main.tf           # Primary resources (users, groups, policies)
├── access_keys.tf    # Access key resources (separated for security clarity)
├── variables.tf      # All input variables with validation
├── outputs.tf        # All outputs with descriptions
├── versions.tf       # Provider requirements
├── data.tf           # Data sources (if needed)
├── README.md         # Documentation
└── examples/
    └── complete/     # Full-featured example
        ├── main.tf
        ├── variables.tf
        └── versions.tf
```

## Data Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                         INPUT VARIABLES                          │
├─────────────────────────────────────────────────────────────────┤
│  var.users          var.groups         var.policies             │
│  (map of users)     (map of groups)    (map of policies)        │
│                                                                  │
│  var.access_keys    var.policy_versions                         │
│  (map of keys)      (map of versions)                           │
└───────────┬─────────────────┬──────────────────┬────────────────┘
            │                 │                  │
            ▼                 ▼                  ▼
┌───────────────────┐ ┌───────────────┐ ┌─────────────────────────┐
│  outscale_user    │ │ outscale_     │ │  outscale_policy        │
│  (for_each)       │ │ user_group    │ │  (for_each)             │
│                   │ │ (for_each)    │ │                         │
│  - user_name      │ │               │ │  - policy_name          │
│  - user_email     │ │ - group_name  │ │  - document             │
│  - path           │ │ - path        │ │  - description          │
│  - policy {}      │ │ - user {}     │ │  - path                 │
└─────────┬─────────┘ │ - policy {}   │ └───────────┬─────────────┘
          │           └───────┬───────┘             │
          │                   │                     │
          ▼                   ▼                     ▼
┌─────────────────────────────────────────────────────────────────┐
│                          OUTPUTS                                 │
├─────────────────────────────────────────────────────────────────┤
│  output.users       output.groups      output.policies          │
│  - user_id          - user_group_id    - policy_id              │
│  - user_name        - name             - policy_name            │
│  - path             - orn              - orn                    │
│  - user_email       - path             - policy_default_        │
│  - creation_date    - creation_date      version_id             │
│                                        - creation_date          │
│  NOTE: User ORN is not exported by the Outscale provider.       │
│  Group and Policy ORNs are available.                           │
│                                                                  │
│  output.access_keys (sensitive)                                  │
│  - access_key_id                                                 │
│  - secret_key                                                    │
│  - state                                                         │
│  - expiration_date                                               │
│  - creation_date                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Variable Definitions

### Users Variable

```hcl
variable "users" {
  description = "Map of EIM users to create"
  type = map(object({
    user_name  = string
    user_email = optional(string)
    path       = optional(string, "/")
    policies = optional(list(object({
      policy_orn         = string
      default_version_id = optional(string)
    })), [])
  }))
  default = {}
}
```

### Groups Variable

```hcl
variable "groups" {
  description = "Map of user groups to create"
  type = map(object({
    user_group_name = string
    path            = optional(string, "/")
    users = optional(list(object({
      user_name = string
      path      = optional(string)
    })), [])
    policies = optional(list(object({
      policy_orn         = string
      default_version_id = optional(string)
    })), [])
  }))
  default = {}
}
```

### Policies Variable

```hcl
variable "policies" {
  description = "Map of managed policies to create"
  type = map(object({
    policy_name = string
    document    = string
    description = optional(string)
    path        = optional(string, "/")
  }))
  default = {}
}
```

### Access Keys Variable

```hcl
variable "access_keys" {
  description = "Map of access keys to create"
  type = map(object({
    user_name       = optional(string)
    state           = optional(string, "ACTIVE")
    expiration_date = optional(string)
  }))
  default = {}
}
```

## Validation Rules

| Variable | Constraint | Validation |
|----------|------------|------------|
| `user_name` | 1-64 chars: alphanumeric + `+`, `=`, `,`, `.`, `@`, `-`, `_` | Regex: `^[a-zA-Z0-9+=,.@_-]{1,64}$` |
| `path` | 1-512 chars, must start and end with `/`, alphanumeric + `/`, `_` | Regex: `^/([a-zA-Z0-9_]+/)*$` or exactly `/` |
| `policy_name` | 1-128 chars | Length check |
| `document` | Max 5120 non-whitespace chars | Length check (validated by API) |
| `state` | ACTIVE or INACTIVE | Enum validation |
| `expiration_date` | ISO 8601 format: `YYYY-MM-DD` or `YYYY-MM-DDTHH:MM:SS.sssZ` | Regex pattern |

### Validation Examples

```hcl
variable "users" {
  # ... type definition ...

  validation {
    condition = alltrue([
      for k, v in var.users : can(regex("^[a-zA-Z0-9+=,.@_-]{1,64}$", v.user_name))
    ])
    error_message = "User names must be 1-64 characters: alphanumeric, +, =, ,, ., @, -, _"
  }

  validation {
    condition = alltrue([
      for k, v in var.users : v.path == "/" || can(regex("^/([a-zA-Z0-9_]+/)+$", v.path))
    ])
    error_message = "Path must begin and end with '/' and contain only alphanumeric characters, underscores, and slashes."
  }
}

variable "access_keys" {
  # ... type definition ...

  validation {
    condition = alltrue([
      for k, v in var.access_keys : contains(["ACTIVE", "INACTIVE"], v.state)
    ])
    error_message = "Access key state must be 'ACTIVE' or 'INACTIVE'."
  }
}
```

## Dependencies

```
┌─────────────┐
│  policies   │ ◄─── Must exist before attachment
└──────┬──────┘
       │
       │ policy_orn reference
       ▼
┌─────────────┐     ┌─────────────┐
│    users    │     │   groups    │
└──────┬──────┘     └─────────────┘
       │
       │ user_name reference
       ▼
┌─────────────┐
│ access_keys │ ◄─── Optional, can be for caller
└─────────────┘
```

### Decision: Access Key User Validation (Hybrid Approach)

For access keys referencing users, we use a hybrid validation approach:

**Internal users** (created in same module):
- Use `depends_on = [outscale_user.this]` to ensure user exists
- Reference the user via module's created resources

**External users** (pre-existing):
- Accept `user_name` string directly
- Let Outscale API validate at apply time (clear error if user not found)
- Document this behavior for users

Rationale: The Outscale provider's `outscale_user` data source only supports
filtering by `user_ids`, not `user_name`. Fetching all users to validate by
name would be inefficient and potentially expose sensitive information.

```hcl
resource "outscale_access_key" "this" {
  for_each = var.create_access_keys ? var.access_keys : {}

  user_name       = each.value.user_name
  state           = each.value.state
  expiration_date = each.value.expiration_date

  # Ensure internal users are created first
  depends_on = [outscale_user.this]
}
```

## Error Handling

- Invalid inputs fail at `terraform plan` with validation errors
- API errors surface as Terraform provider errors
- Missing dependencies (e.g., non-existent policy ORN) fail at apply time
- External user references for access keys are validated by the API at apply time

## Security Considerations

1. **Secret Keys in State**: Document that access key secrets are stored in Terraform state
2. **State Encryption**: Recommend using encrypted backend (S3 with SSE, etc.)
3. **Access Key Rotation**: Encourage short expiration dates
4. **Least Privilege**: Example policies should demonstrate minimal permissions

## Provider Resource Reference (Verified)

### outscale_user

**Arguments:**
| Name | Required | Description |
|------|----------|-------------|
| `user_name` | Yes | 1-64 chars: alphanumeric + `+`, `=`, `,`, `.`, `@`, `-`, `_` |
| `user_email` | No | Email address of the EIM user |
| `path` | No | Path to user (default: `/`). Must begin/end with `/` |

**Nested `policy` block:**
| Name | Required | Description |
|------|----------|-------------|
| `policy_orn` | Yes | ORN of the policy to attach |
| `default_version_id` | No | Version ID to use (e.g., `V1`, `V2`) |

**Exported Attributes:**
- `user_id` - ID of the EIM user
- `user_name` - Name of the EIM user
- `user_email` - Email address
- `path` - Path to the user
- `creation_date` - UTC creation timestamp
- `last_modification_date` - UTC last modified timestamp

**Note:** `orn` is NOT exported for users (only for groups and policies).

### outscale_user_group

**Arguments:**
| Name | Required | Description |
|------|----------|-------------|
| `user_group_name` | Yes | Name of the group |
| `path` | No | Path to group (default: `/`) |

**Nested `user` block:**
| Name | Required | Description |
|------|----------|-------------|
| `user_name` | Yes | Name of user to add |
| `path` | No | Path of the user |

**Nested `policy` block:**
| Name | Required | Description |
|------|----------|-------------|
| `policy_orn` | Yes | ORN of the policy to attach |
| `default_version_id` | No | Version ID to use |

**Exported Attributes:**
- `user_group_id` - ID of the user group
- `name` - Name of the user group
- `orn` - Outscale Resource Name (ORN)
- `path` - Path to the user group
- `creation_date` - UTC creation timestamp
- `last_modification_date` - UTC last modified timestamp

### outscale_policy

**Arguments:**
| Name | Required | Description |
|------|----------|-------------|
| `policy_name` | Yes | Name of the policy |
| `document` | Yes | JSON policy document (max 5120 non-whitespace chars) |
| `description` | No | Description (0-1000 chars) |
| `path` | No | Path to policy |

**Exported Attributes:**
- `policy_id` - ID of the policy
- `policy_name` - Name of the policy
- `orn` - Outscale Resource Name (ORN)
- `policy_default_version_id` - ID of default version (V1 initially)
- `path` - Path to the policy
- `description` - Policy description
- `is_linkable` - Whether policy can be linked
- `resources_count` - Number of attached resources
- `creation_date` - UTC creation timestamp
- `last_modification_date` - UTC last modified timestamp

### outscale_policy_version

**Arguments:**
| Name | Required | Description |
|------|----------|-------------|
| `policy_orn` | Yes | ORN of the parent policy |
| `document` | Yes | JSON policy document |
| `set_as_default` | No | If true, make this version the default |

**Exported Attributes:**
- `version_id` - ID of the version (V2, V3, etc.)
- `body` - The policy document
- `default_version` - Boolean if this is default
- `creation_date` - UTC creation timestamp

**Note:** Initial policy creation sets version to V1. Additional versions increment (V2, V3, etc.). Maximum 5 versions per policy.

### outscale_access_key

**Arguments:**
| Name | Required | Description |
|------|----------|-------------|
| `user_name` | No | User to create key for (default: caller) |
| `state` | No | `ACTIVE` or `INACTIVE` (default: ACTIVE) |
| `expiration_date` | No | ISO 8601 date: `YYYY-MM-DD` or full timestamp |

**Exported Attributes:**
- `access_key_id` - ID of the access key
- `secret_key` - Secret key (sensitive, stored in state)
- `state` - Current state
- `expiration_date` - Expiration timestamp
- `creation_date` - UTC creation timestamp
- `last_modification_date` - UTC last modified timestamp

**Security Warning:** The `secret_key` is stored in Terraform state. Use encrypted state backends.
