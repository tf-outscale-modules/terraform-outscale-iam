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

variable "create_api_access_policy" {
  description = "Whether to manage the account API access policy when api_access_policy is set"
  type        = bool
  default     = true
}

variable "create_api_access_rules" {
  description = "Whether to create API access rules"
  type        = bool
  default     = true
}

variable "create_cas" {
  description = "Whether to create Certificate Authorities. Keep true when api_access_rules reference them through ca_keys"
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

################################################################################
# API Access Policy Variable
################################################################################

variable "api_access_policy" {
  description = "Account-wide API access policy (a singleton: one per Outscale account). null leaves the policy untouched. WARNING: removing this input later does NOT reset the policy on the server; first apply max_access_key_expiration_seconds = 0 and require_trusted_env = false. A trusted session needs an expiration date on every access key and a CA on every API access rule, and can lock callers out."
  type = object({
    max_access_key_expiration_seconds = number
    require_trusted_env               = bool
    require_trusted_env_secure_mode   = optional(bool)
  })
  default = null

  validation {
    condition = var.api_access_policy == null ? true : (
      floor(var.api_access_policy.max_access_key_expiration_seconds) == var.api_access_policy.max_access_key_expiration_seconds &&
      var.api_access_policy.max_access_key_expiration_seconds >= 0 &&
      var.api_access_policy.max_access_key_expiration_seconds <= 3153600000
    )
    error_message = "max_access_key_expiration_seconds must be an integer between 0 and 3153600000 inclusive."
  }

  validation {
    condition = var.api_access_policy == null ? true : (
      !var.api_access_policy.require_trusted_env || var.api_access_policy.max_access_key_expiration_seconds > 0
    )
    error_message = "require_trusted_env = true requires max_access_key_expiration_seconds greater than 0."
  }

  validation {
    condition = var.api_access_policy == null ? true : (
      !coalesce(var.api_access_policy.require_trusted_env_secure_mode, false) || var.api_access_policy.require_trusted_env
    )
    error_message = "require_trusted_env_secure_mode = true requires require_trusted_env = true."
  }
}

################################################################################
# Certificate Authorities Variable
################################################################################

variable "cas" {
  description = "Map of client Certificate Authorities for API access rules. ca_pem is the PUBLIC CA certificate in PEM format (not a secret, so not sensitive); never pass a private key. Changing ca_pem replaces the CA."
  type = map(object({
    ca_pem      = string
    description = optional(string)
  }))
  default = {}

  validation {
    condition = alltrue([
      for k, v in var.cas : can(regex("-----BEGIN CERTIFICATE-----", v.ca_pem))
    ])
    error_message = "ca_pem must be a PEM certificate containing '-----BEGIN CERTIFICATE-----'."
  }

  validation {
    condition = alltrue([
      for k, v in var.cas : !can(regex("PRIVATE KEY", v.ca_pem))
    ])
    error_message = "ca_pem must contain only the public CA certificate; private key material is not accepted."
  }
}

################################################################################
# API Access Rules Variable
################################################################################

variable "api_access_rules" {
  description = "Map of API access rules. ip_ranges are canonical CIDRs (for example 192.0.2.0/24 or 192.0.2.5/32). CAs are referenced by ca_keys (keys of var.cas) and/or ca_ids (existing CA IDs); cns requires a CA. Applying a rule restricts API calls to the listed sources: include the address Terraform runs from. Unset sets keep their server value (they cannot be cleared by omission)."
  type = map(object({
    description = optional(string)
    ip_ranges   = optional(set(string), [])
    ca_ids      = optional(set(string), [])
    ca_keys     = optional(set(string), [])
    cns         = optional(set(string), [])
  }))
  default = {}

  validation {
    condition = alltrue([
      for k, v in var.api_access_rules : length(v.ip_ranges) + length(v.ca_ids) + length(v.ca_keys) > 0
    ])
    error_message = "Each API access rule needs at least one of ip_ranges, ca_ids or ca_keys."
  }

  validation {
    condition = alltrue([
      for k, v in var.api_access_rules : length(v.cns) == 0 || length(v.ca_ids) + length(v.ca_keys) > 0
    ])
    error_message = "cns requires at least one CA (ca_ids or ca_keys)."
  }

  validation {
    condition = alltrue(flatten([
      for k, v in var.api_access_rules : [
        for cidr in v.ip_ranges : try(cidrsubnet(cidr, 0, 0) == cidr, false)
      ]
    ]))
    error_message = "ip_ranges entries must be canonical CIDRs whose address is the network address, for example 192.0.2.0/24 or 192.0.2.5/32."
  }

  validation {
    condition = alltrue(flatten([
      for k, v in var.api_access_rules : [for ck in v.ca_keys : contains(keys(var.cas), ck)]
    ]))
    error_message = "Every ca_keys entry must be a key of the cas variable."
  }

  validation {
    condition = !var.create_api_access_rules || var.create_cas || alltrue([
      for k, v in var.api_access_rules : length(v.ca_keys) == 0
    ])
    error_message = "ca_keys references CAs created by this module, so create_cas must be true; set create_cas = true or use ca_ids with existing CA IDs."
  }

  validation {
    condition = alltrue(flatten([
      for k, v in var.api_access_rules : [for id in v.ca_ids : startswith(id, "ca-")]
    ]))
    error_message = "ca_ids entries must start with 'ca-'."
  }
}
