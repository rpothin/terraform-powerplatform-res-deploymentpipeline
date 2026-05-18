# terraform-powerplatform-res-deploymentpipeline

Terraform module for configuring a Power Platform Custom Pipelines deployment pipeline, including environment registration, pipeline creation, stage setup, and optional sharing — all managed as Dataverse records in a Pipelines Host environment.

## What this module manages

This module automates all four configuration steps of a Power Platform Custom Pipelines Host:

1. **Environment registration** — Registers pre-existing Power Platform environments as `deploymentenvironment` Dataverse records in the Pipelines Host. Includes async validation detection to ensure each environment passes Pipelines Host validation before the pipeline is created.
2. **Pipeline creation** — Creates the `deploymentpipeline` Dataverse record.
3. **Stage setup** — Links the dev (source) environment to the pipeline and creates an ordered linear chain of `deploymentstage` records. Supports 1–6 target stages.
4. **Pipeline sharing** (optional) — Shares the pipeline with a Dataverse team via `GrantAccess`.

## Prerequisites

- A Pipelines Host Power Platform environment must already exist (managed externally)
- All Power Platform environments to be registered must already exist
- The caller must have Dataverse system user access to the Pipelines Host environment
- The Power Platform Terraform provider must be authenticated (OIDC recommended)

## Authentication

This module uses the `microsoft/power-platform` provider. Authenticate using OIDC federated credentials:

```bash
export POWER_PLATFORM_TENANT_ID="<tenant-id>"
export POWER_PLATFORM_CLIENT_ID="<client-id>"
export ARM_USE_OIDC=true
```

## Usage pattern

This module is designed to be combined with environment provisioning modules (e.g., `powerplatform_environment`) to provide a complete ALM setup. The `environments` map accepts pre-existing environment IDs — provisioning is the caller's responsibility.

See [examples/basic](./examples/basic/) for a minimal dev → test configuration and [examples/complete](./examples/complete/) for a full dev → test → staging → prod configuration with approval gates and sharing.
