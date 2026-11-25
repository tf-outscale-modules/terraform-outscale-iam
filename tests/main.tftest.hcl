# Plan-mode unit tests: no Outscale account or credentials needed.

# The PEM literals below are placeholders, not real certificates: the module only checks the PEM marker.
mock_provider "outscale" {}

################################################################################
# Opt-in behaviour
################################################################################

run "defaults_create_no_api_access_resources" {
  command = plan

  assert {
    condition     = length(outscale_ca.this) == 0 && length(outscale_api_access_rule.this) == 0 && length(outscale_api_access_policy.this) == 0
    error_message = "No API access resource may be planned with default inputs."
  }

  assert {
    condition     = output.cas == {} && output.ca_ids == {} && output.api_access_rules == {} && output.api_access_rule_ids == {} && output.api_access_policy == {}
    error_message = "All API access outputs must be empty maps by default."
  }
}

run "existing_inputs_unchanged" {
  command = plan

  variables {
    users = {
      alice = { user_name = "alice" }
    }
  }

  assert {
    condition     = length(outscale_user.this) == 1 && length(outscale_api_access_policy.this) == 0
    error_message = "Existing inputs must plan as before and add no API access resource."
  }
}

run "toggles_disable_resources" {
  command = plan

  variables {
    create_cas               = false
    create_api_access_rules  = false
    create_api_access_policy = false
    cas                      = { corp = { ca_pem = "-----BEGIN CERTIFICATE-----\nMIIBplaceholder\n-----END CERTIFICATE-----\n" } }
    api_access_rules         = { office = { ip_ranges = ["192.0.2.0/24"] } }
    api_access_policy        = { max_access_key_expiration_seconds = 31536000, require_trusted_env = false }
  }

  assert {
    condition     = length(outscale_ca.this) == 0 && length(outscale_api_access_rule.this) == 0 && length(outscale_api_access_policy.this) == 0
    error_message = "create_* = false must suppress every API access resource."
  }
}

################################################################################
# API access policy
################################################################################

run "policy_cap_only" {
  command = plan

  variables {
    api_access_policy = { max_access_key_expiration_seconds = 31536000, require_trusted_env = false }
  }

  assert {
    condition     = length(outscale_api_access_policy.this) == 1 && outscale_api_access_policy.this["this"].max_access_key_expiration_seconds == 31536000 && outscale_api_access_policy.this["this"].require_trusted_env == false
    error_message = "One policy with the requested cap must be planned."
  }
}

run "policy_trusted_env_and_secure_mode" {
  command = plan

  variables {
    api_access_policy = {
      max_access_key_expiration_seconds = 3153600000
      require_trusted_env               = true
      require_trusted_env_secure_mode   = true
    }
    api_access_rules = { office = { ca_keys = ["corp"] } }
    cas              = { corp = { ca_pem = "-----BEGIN CERTIFICATE-----\nMIIBplaceholder\n-----END CERTIFICATE-----\n" } }
  }

  assert {
    condition     = outscale_api_access_policy.this["this"].require_trusted_env_secure_mode == true
    error_message = "Secure mode must be sent when set."
  }
}

run "policy_rejects_out_of_range_high" {
  command = plan

  variables {
    api_access_policy = { max_access_key_expiration_seconds = 3153600001, require_trusted_env = false }
  }

  expect_failures = [var.api_access_policy]
}

run "policy_rejects_negative" {
  command = plan

  variables {
    api_access_policy = { max_access_key_expiration_seconds = -1, require_trusted_env = false }
  }

  expect_failures = [var.api_access_policy]
}

run "policy_rejects_fraction" {
  command = plan

  variables {
    api_access_policy = { max_access_key_expiration_seconds = 1.5, require_trusted_env = false }
  }

  expect_failures = [var.api_access_policy]
}

run "policy_rejects_trusted_env_without_cap" {
  command = plan

  variables {
    api_access_policy = { max_access_key_expiration_seconds = 0, require_trusted_env = true }
  }

  expect_failures = [var.api_access_policy]
}

run "policy_rejects_secure_mode_without_trusted_env" {
  command = plan

  variables {
    api_access_policy = {
      max_access_key_expiration_seconds = 31536000
      require_trusted_env               = false
      require_trusted_env_secure_mode   = true
    }
  }

  expect_failures = [var.api_access_policy]
}

################################################################################
# Certificate Authorities
################################################################################

run "ca_valid" {
  command = plan

  variables {
    cas = { corp = { ca_pem = "-----BEGIN CERTIFICATE-----\nMIIBplaceholder\n-----END CERTIFICATE-----\n", description = "Corporate CA" } }
  }

  assert {
    condition     = length(outscale_ca.this) == 1 && outscale_ca.this["corp"].description == "Corporate CA"
    error_message = "One CA keyed corp must be planned."
  }
}

run "ca_rejects_non_pem" {
  command = plan

  variables {
    cas = { corp = { ca_pem = "not a certificate" } }
  }

  expect_failures = [var.cas]
}

run "ca_rejects_private_key" {
  command = plan

  variables {
    cas = { corp = { ca_pem = "-----BEGIN CERTIFICATE-----\nMIIBplaceholder\n-----END CERTIFICATE-----\n-----BEGIN TEST PRIVATE KEY-----\nx\n-----END TEST PRIVATE KEY-----\n" } }
  }

  expect_failures = [var.cas]
}

################################################################################
# API access rules
################################################################################

run "rule_ip_only" {
  command = plan

  variables {
    api_access_rules = { office = { ip_ranges = ["192.0.2.0/24", "198.51.100.5/32"], description = "Office" } }
  }

  assert {
    condition     = length(outscale_api_access_rule.this) == 1 && length(outscale_api_access_rule.this["office"].ip_ranges) == 2
    error_message = "One rule with two ranges must be planned."
  }
}

run "rule_ip_order_is_irrelevant" {
  command = plan

  variables {
    api_access_rules = { office = { ip_ranges = ["198.51.100.5/32", "192.0.2.0/24"] } }
  }

  assert {
    condition     = outscale_api_access_rule.this["office"].ip_ranges == toset(["192.0.2.0/24", "198.51.100.5/32"])
    error_message = "ip_ranges is a set; order must not matter."
  }
}

run "rule_with_module_ca_and_existing_ca" {
  command = plan

  variables {
    cas              = { corp = { ca_pem = "-----BEGIN CERTIFICATE-----\nMIIBplaceholder\n-----END CERTIFICATE-----\n" } }
    api_access_rules = { mtls = { ca_keys = ["corp"], ca_ids = ["ca-12345678"], cns = ["client.example.com"] } }
  }

  assert {
    condition     = length(outscale_ca.this) == 1 && length(outscale_api_access_rule.this["mtls"].cns) == 1
    error_message = "CA and rule must both be planned."
  }
}

run "rule_rejects_empty" {
  command = plan

  variables {
    api_access_rules = { empty = {} }
  }

  expect_failures = [var.api_access_rules]
}

run "rule_rejects_cns_without_ca" {
  command = plan

  variables {
    api_access_rules = { bad = { ip_ranges = ["192.0.2.0/24"], cns = ["client.example.com"] } }
  }

  expect_failures = [var.api_access_rules]
}

run "rule_rejects_bare_ip" {
  command = plan

  variables {
    api_access_rules = { bad = { ip_ranges = ["192.0.2.7"] } }
  }

  expect_failures = [var.api_access_rules]
}

run "rule_rejects_non_canonical_cidr" {
  command = plan

  variables {
    api_access_rules = { bad = { ip_ranges = ["192.0.2.7/24"] } }
  }

  expect_failures = [var.api_access_rules]
}

run "rule_rejects_unknown_ca_key" {
  command = plan

  variables {
    api_access_rules = { bad = { ca_keys = ["missing"] } }
  }

  expect_failures = [var.api_access_rules]
}

run "rule_rejects_ca_keys_when_cas_disabled" {
  command = plan

  variables {
    create_cas       = false
    cas              = { corp = { ca_pem = "-----BEGIN CERTIFICATE-----\nMIIBplaceholder\n-----END CERTIFICATE-----\n" } }
    api_access_rules = { mtls = { ca_keys = ["corp"] } }
  }

  expect_failures = [var.api_access_rules]
}

run "rule_rejects_bad_ca_id" {
  command = plan

  variables {
    api_access_rules = { bad = { ca_ids = ["xx-123"] } }
  }

  expect_failures = [var.api_access_rules]
}

################################################################################
# Check blocks (warnings)
################################################################################

run "check_trusted_env_rule_without_ca" {
  command = plan

  variables {
    api_access_policy = { max_access_key_expiration_seconds = 31536000, require_trusted_env = true }
    api_access_rules  = { office = { ip_ranges = ["192.0.2.0/24"] } }
  }

  expect_failures = [check.api_access_trusted_env_rules_have_ca]
}

run "check_expiry_cap_key_without_expiration" {
  command = plan

  variables {
    api_access_policy = { max_access_key_expiration_seconds = 31536000, require_trusted_env = false }
    users             = { alice = { user_name = "alice" } }
    access_keys       = { alice_key = { user_name = "alice" } }
  }

  expect_failures = [check.api_access_expiry_cap_keys_have_expiration]
}

run "checks_quiet_on_safe_combination" {
  command = plan

  variables {
    api_access_policy = { max_access_key_expiration_seconds = 31536000, require_trusted_env = true }
    cas               = { corp = { ca_pem = "-----BEGIN CERTIFICATE-----\nMIIBplaceholder\n-----END CERTIFICATE-----\n" } }
    api_access_rules  = { mtls = { ca_keys = ["corp"] } }
    users             = { alice = { user_name = "alice" } }
    access_keys       = { alice_key = { user_name = "alice", expiration_date = "2027-01-01" } }
  }

  assert {
    condition     = length(outscale_api_access_policy.this) == 1
    error_message = "Safe combination must plan without check failures."
  }
}
