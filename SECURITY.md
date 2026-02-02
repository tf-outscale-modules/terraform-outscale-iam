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
  OUTSCALE_ACCESSKEYID: $OUTSCALE_ACCESS_KEY  # From CI secrets
  OUTSCALE_SECRETKEYID: $OUTSCALE_SECRET_KEY  # From CI secrets

# Bad: Hardcoded values
# OUTSCALE_ACCESSKEYID: "AKIAXXXXXXXX"  # NEVER DO THIS
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
| 1.x     | Active support   |
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
