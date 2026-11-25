# Changelog

All notable changes to this project will be documented in this file.

## [2.0.0] - 2026-11-25
- Add API access policy, rules and CA management (requires provider ~> 1.9, major)

Add opt-in inputs api_access_policy, api_access_rules and cas, wrapping
outscale_api_access_policy, outscale_api_access_rule and outscale_ca, with
validation blocks, lock-out check blocks, outputs, plan-mode unit tests
(tests/main.tftest.hcl), an updated complete example and SECURITY.md guidance.
Nothing is created unless the new inputs are set. CA and rules were verified
against a real account (second plan empty); the policy was plan-only.

Upgrade notes (major, v2.0.0): the outscale provider floor is raised from
~> 1.8 to ~> 1.9 because require_trusted_env_secure_mode exists only from
provider v1.9.0. Bump the provider constraint and run tofu init -upgrade; no
input, output or resource address changes, so the first plan is empty.
Replacement warnings: changing a CA's ca_pem replaces the CA. The API access
policy is account-wide and its provider delete is a no-op: removing
api_access_policy does not reset it on the server (apply cap 0 and
require_trusted_env false first). Rule sets cannot be cleared by omission.
- chore(deps): upgrade outscale provider to ~> 1.8

- Bump the outscale provider constraint to ~> 1.8 (module and examples).
- docs: use OSC_ACCESS_KEY/OSC_SECRET_KEY/OSC_REGION; the legacy
  OUTSCALE_* environment variables are ignored since provider 1.6.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
- Upgrade OpenSpec to 1.14.0 with Claude Code and OpenCode skills

Pin @fission-ai/openspec 1.14.0 in mise.toml and regenerate the
OpenSpec instruction files for Claude Code and OpenCode (skills
delivery). Legacy opsx-* command files are removed in favor of skills.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
- Adds project purpose to config

Adds a description of the project's purpose to the configuration file.

This provides context for users and contributors, outlining the module's role in managing Outscale IAM resources.
## [1.0.1] - 2026-02-02
- Adds OpenSpec configuration file

Adds a configuration file (`openspec/config.yaml`) to define standards and guidelines for Terraform module development.

The configuration outlines requirements for file structure, variables, outputs, resources, providers, security, documentation, testing, and compatibility.

It also specifies rules for proposals, specifications, design, and tasks related to module development.
## [1.0.0] - 2026-02-02
- Updates outscale provider version constraint.

Relax the version constraint for the outscale provider in the terraform module.

This allows for more flexibility in version selection and enables the use of newer compatible versions.
- Updates documentation and configurations

Corrects minor formatting issues in the README and other documentation files,
including line break inconsistencies and a missing newline in config.yaml.

Updates the outscale provider version in the README.
- Implements Outscale IAM Terraform module

This commit introduces a fully functional Terraform module for managing Outscale IAM (EIM) resources.

The module allows users to create and manage EIM users, user groups, and managed policies, and access keys. It provides conditional resource creation, comprehensive outputs, and input validation for secure and flexible IAM management.

Includes complete documentation, examples, and testing guidelines.
- Adds OpenSpec workflow commands

Introduces a set of commands for managing OpenSpec workflows, including apply, archive, bulk archive, continue, explore, fast forward, new, sync, and verify.

These commands facilitate the creation, implementation, and management of changes within a structured, artifact-driven approach.

The changes introduce several new skills and workflows related to OpenSpec, expanding the capabilities for managing code changes and design specifications.
- Initial commit

