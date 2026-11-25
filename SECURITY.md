# Security Policy

## Reporting Security Issues

If you discover a security vulnerability in this module, please report it responsibly:

1. **Do NOT** open a public GitHub/GitLab issue
2. Email security concerns to the maintainers directly
3. Include detailed steps to reproduce the vulnerability
4. Allow reasonable time for a fix before public disclosure

## Security Best Practices

When using this module in production, follow these security guidelines:

### State File Security

**Critical**: Terraform state contains sensitive data including access key secrets.

```hcl
# Use encrypted remote state - Example with S3-compatible backend
terraform {
  backend "s3" {
    bucket         = "my-terraform-state"
    key            = "iam/terraform.tfstate"
    region         = "eu-west-2"
    encrypt        = true
    dynamodb_table = "terraform-locks"

    # For Outscale OSU (Object Storage Unit)
    endpoint                    = "https://osu.eu-west-2.outscale.com"
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    force_path_style            = true
  }
}
```

**Required measures:**
- Enable encryption at rest for state storage
- Restrict access to state files (IAM policies)
- Use state locking to prevent concurrent modifications
- Never commit `.tfstate` files to version control

### Access Key Management

1. **Set Expiration Dates**: Always set `expiration_date` on access keys
   ```hcl
   access_keys = {
     service_key = {
       user_name       = "service-account"
       expiration_date = "2025-06-01"  # Max 1 year recommended
     }
   }
   ```

2. **Rotate Regularly**: Implement key rotation procedures
   - Create new key
   - Update applications
   - Deactivate old key
   - Delete old key after verification

3. **Use INACTIVE State for Staging**:
   ```hcl
   access_keys = {
     new_key = {
       user_name = "service-account"
       state     = "INACTIVE"  # Activate after testing
     }
   }
   ```

### Policy Design

Follow the principle of least privilege:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "fcu:DescribeInstances",
        "fcu:DescribeVolumes"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Deny",
      "Action": [
        "eim:*",
        "fcu:DeleteVolume",
        "fcu:TerminateInstances"
      ],
      "Resource": "*"
    }
  ]
}
```

**Guidelines:**
- Start with deny-all, explicitly allow needed actions
- Use explicit Deny statements for dangerous operations
- Avoid wildcard (`*`) actions where possible
- Document policy purpose in the `description` field

### Environment Isolation

Separate IAM resources by environment:

```hcl
module "iam_prod" {
  source = "path/to/outscale-iam"

  users = {
    deployer = {
      user_name = "prod-deployer"
      path      = "/prod/services/"
    }
  }
}

module "iam_staging" {
  source = "path/to/outscale-iam"

  users = {
    deployer = {
      user_name = "staging-deployer"
      path      = "/staging/services/"
    }
  }
}
```

### Audit and Monitoring

1. **Enable CloudTrail equivalent** (if available) to log IAM API calls
2. **Review access regularly**: List users and their permissions periodically
3. **Monitor for anomalies**: Unexpected policy changes, new admin users, etc.

### Secrets in CI/CD

Never hardcode credentials in CI/CD pipelines:

```yaml
# Good: Use CI/CD secrets management
variables:
  OSC_ACCESS_KEY: $OUTSCALE_ACCESS_KEY  # From CI secrets
  OSC_SECRET_KEY: $OUTSCALE_SECRET_KEY  # From CI secrets

# Bad: Hardcoded values
# OSC_ACCESS_KEY: "AKIAXXXXXXXX"  # NEVER DO THIS
```

## Sensitive Outputs

The `access_keys` output is marked sensitive. To use it in automation:

```hcl
# In calling module - preserves sensitivity
output "service_key" {
  value     = module.iam.access_keys["service"]
  sensitive = true
}

# To reveal in CLI (use with caution)
# terraform output -json access_keys
```

## API Access Control

The optional `api_access_policy`, `api_access_rules` and `cas` inputs change **account-wide** API access. Nothing is created unless they are set.

### Scope and persistence

- The API access policy is a singleton per Outscale account. Manage it from one stack only.
- The provider's delete for `outscale_api_access_policy` does nothing: `tofu destroy`, or removing `api_access_policy`, leaves the policy active on the server. To disable it, first apply `max_access_key_expiration_seconds = 0` and `require_trusted_env = false`, then remove the input.

### Lock-out scenarios

| Scenario | Effect | Mitigation |
|----------|--------|------------|
| `max_access_key_expiration_seconds > 0` | Every access key needs an expiration date within the cap; the cap must exceed the remaining life of every existing key | Set `expiration_date` on all keys; the module warns about its own keys (`check`), not unmanaged ones |
| `require_trusted_env = true` | Trusted session: every API access rule needs a CA, users need trusted access keys and MFA on Cockpit v2 | Add a CA to every rule first; apply the policy last, with a trusted key; keep a break-glass path |
| `require_trusted_env_secure_mode = true` | Also restricts CLI use of certain API calls | Test in a non-production account |
| Rules with `ip_ranges` | Calls from outside every rule are refused, including Terraform's own | Include the runner and operator egress CIDRs in the first rule; the module cannot know them |

Apply order: CAs, then rules, then the policy, one change per apply, with an independent session kept open.

### Recovery

**Recovery path unverified.** Outscale documents `UpdateApiAccessPolicy` with login/password authentication, but whether those calls bypass API access rules and trusted sessions has not been verified against a real account. Until it is, contact Outscale support if a lock-out occurs.

### Certificate Authorities and state

`ca_pem` is the **public** certificate of the CA that signs API client certificates. It is not a secret, so the input is not `sensitive`, and the provider offers no write-only argument for it. The module rejects values containing `PRIVATE KEY` so a private key cannot be passed by mistake.

| Lands in state | Sensitivity | Mitigation |
|----------------|-------------|------------|
| CA certificate (PEM) and fingerprint | public | none needed |
| API access rule IP ranges and CNs | network topology | encrypted state, restricted access |
| API access policy values | low | encrypted state |

### Least privilege

The identity running Terraform needs the EIM permissions for the API access policy, API access rule and CA actions only when these inputs are used (see https://docs.outscale.com/api: `ReadApiAccessPolicy`, `UpdateApiAccessPolicy`, `CreateApiAccessRule`, `ReadApiAccessRules`, `UpdateApiAccessRule`, `DeleteApiAccessRule`, `CreateCa`, `ReadCas`, `UpdateCa`, `DeleteCa`). These 10 action names were confirmed against the API reference; a least-privilege run with a token limited to them has not yet been performed.

## Known Security Considerations

| Concern | Mitigation |
|---------|------------|
| Secret keys in state | Use encrypted remote state backends |
| Overly permissive policies | Review policies; use explicit Deny statements |
| Long-lived access keys | Set expiration dates; implement rotation |
| Shared credentials | Create per-user/per-service credentials |
| Orphaned resources | Use `terraform destroy` when decommissioning |

## Supported Versions

| Version | Security Updates |
|---------|------------------|
| 2.x     | Active support   |
| 1.x     | Security fixes only |
| < 1.0   | No longer supported |

## Security Checklist

Before deploying to production:

- [ ] Remote state with encryption enabled
- [ ] State file access restricted to authorized personnel
- [ ] All access keys have expiration dates
- [ ] Policies follow least privilege principle
- [ ] No hardcoded credentials in code or CI/CD
- [ ] Separate IAM resources per environment
- [ ] Audit logging enabled (if available)
- [ ] Security review of all custom policies
