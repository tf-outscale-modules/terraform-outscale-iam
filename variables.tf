################################################################################
# Conditional Creation Variables
################################################################################

variable "create_users" {
  description = "Whether to create EIM users"
  type        = bool
  default     = true
}

variable "create_groups" {
  description = "Whether to create user groups"
  type        = bool
  default     = true
}

variable "create_policies" {
  description = "Whether to create managed policies"
  type        = bool
  default     = true
}

variable "create_access_keys" {
  description = "Whether to create access keys"
  type        = bool
  default     = true
}

variable "create_policy_versions" {
  description = "Whether to create policy versions"
  type        = bool
  default     = true
}

################################################################################
# Users Variable
################################################################################

variable "users" {
  description = "Map of EIM users to create. Each user can have policies attached via the policies list."
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

  validation {
    condition = alltrue([
      for k, v in var.users : can(regex("^[a-zA-Z0-9+=,.@_-]{1,64}$", v.user_name))
    ])
    error_message = "User names must be 1-64 characters containing only alphanumeric characters, +, =, ,, ., @, -, or _."
  }

  validation {
    condition = alltrue([
      for k, v in var.users : v.path == "/" || can(regex("^/([a-zA-Z0-9_]+/)+$", v.path))
    ])
    error_message = "Path must begin and end with '/' and contain only alphanumeric characters, underscores, and slashes."
  }
}

################################################################################
# Groups Variable
################################################################################

variable "groups" {
  description = "Map of user groups to create. Groups can contain users and have policies attached."
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

  validation {
    condition = alltrue([
      for k, v in var.groups : v.path == "/" || can(regex("^/([a-zA-Z0-9_]+/)+$", v.path))
    ])
    error_message = "Path must begin and end with '/' and contain only alphanumeric characters, underscores, and slashes."
  }
}

################################################################################
# Policies Variable
################################################################################

variable "policies" {
  description = "Map of managed policies to create. The document should be a valid JSON policy string."
  type = map(object({
    policy_name = string
    document    = string
    description = optional(string)
    path        = optional(string, "/")
  }))
  default = {}

  validation {
    condition = alltrue([
      for k, v in var.policies : can(regex("^.{1,128}$", v.policy_name))
    ])
    error_message = "Policy names must be between 1 and 128 characters."
  }
}

################################################################################
# Policy Versions Variable
################################################################################

variable "policy_versions" {
  description = "Map of policy versions to create. Used to add additional versions to existing policies."
  type = map(object({
    policy_orn     = string
    document       = string
    set_as_default = optional(bool, false)
  }))
  default = {}
}

################################################################################
# Access Keys Variable
################################################################################

variable "access_keys" {
  description = "Map of access keys to create. If user_name is omitted, the key is created for the caller."
  type = map(object({
    user_name       = optional(string)
    state           = optional(string, "ACTIVE")
    expiration_date = optional(string)
  }))
  default = {}

  validation {
    condition = alltrue([
      for k, v in var.access_keys : contains(["ACTIVE", "INACTIVE"], v.state)
    ])
    error_message = "Access key state must be 'ACTIVE' or 'INACTIVE'."
  }
}
