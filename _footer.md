## Future Roadmap

The items below represent areas under consideration for future versions of this module. They are shared for transparency and community feedback — nothing listed here constitutes a commitment or a release timeline.

| # | Area | Description |
|---|------|-------------|
| 1 | **Pipeline extensibility hooks** | Support for cloud flow– or webhook-based pre/post deployment steps per stage (`extend-pipelines` feature). This would allow custom logic to run before or after each deployment without leaving the pipeline orchestration. |
| 2 | **GitHub solution export integration** | Support for configuring automatic solution export to a GitHub repository as part of the pipeline (`extend-pipelines-github-export` feature), enabling a GitOps-aligned ALM flow directly from Pipelines. |
| 3 | **Multiple access groups** | The current module accepts a single Entra ID security group. A future version may accept a list to enable finer-grained access control — for example, separate groups per stage or per role (approver vs. deployer). |
| 4 | **Delegated deployment SPN provisioning guidance** | When `use_delegated_deployment = true`, the caller must supply the Azure AD client ID (`deployment_spn_client_id`) of a service principal already registered as an application user in Dataverse. A future version may include helper resources or documented runbook steps to reduce this out-of-band setup burden. |
| 5 | **Record ownership (`ownerid`)** | Explicitly setting the owner of Dataverse records created by this module is not currently supported. The Power Platform provider serialises the `ownerid` lookup column in a format rejected by the `deploymentenvironment`, `deploymentpipeline`, and `deploymentstage` Dataverse entities. Records are owned by the identity running Terraform apply. This will be re-evaluated once provider-level support for lookup-column object format is confirmed. |

Feedback and pull requests are welcome. See [CONTRIBUTING.md](./CONTRIBUTING.md) for guidelines.

## Known Platform Limitations

These are known limitations in the Power Platform API that affect this module's behavior. They are not bugs in the module itself.

| # | Limitation | Impact | Workaround |
|---|-----------|--------|------------|
| L1 | **`deploymentpipeline` and `deploymentstage` records cannot be deleted via API** | A Microsoft System plugin (`Microsoft.Crm.ObjectModel.CustomBusinessEntityService`) fires on DELETE and PATCH-to-deactivate of these record types, returning error `0x80073002` (duplicate unique constraint violation). This also occurs from the Power Platform UI. | Records remain in the Pipelines Host after `terraform destroy`. Manual cleanup via the Pipelines Host UI is not possible for these record types. `terraform destroy` will fail on the stage/pipeline deletion step — this is expected. |
| L2 | **`deploymentenvironment` records cannot be cleaned up by teardown** | Because teardown fails at stage deletion (L1), Terraform stops before reaching `deploymentenvironment` destroy calls. On a fresh apply in the same host, Dataverse duplicate detection (`0x80040265`) would block creating the same environment registration again. | This module performs a **find-or-create** check: before creating a `deploymentenvironment` record, it queries for an existing active record with the same `environmentid`. If found, the existing record is reused. This makes repeated applies idempotent even after failed teardowns. |

## Known Deviations from AVM

| ID | Specification | Deviation | Rationale |
|----|---------------|-----------|-----------|
| D1 | TFFR3 — Provider scope | Uses `microsoft/power-platform` provider instead of `azurerm`/`azapi` | Power Platform resources are not Azure resources |
| D2 | TFFR1 — Module registry | Not published under `Azure/` namespace | Community module outside AVM certification scope |
| D3 | TFNFR5 — Test tooling | Uses Trivy instead of Checkov; tflint without `azurerm` ruleset | Scan targets are Power Platform resources, not Azure |
| D4 | TFNFR36 — Test provider | No `prevent_deletion_if_contains_resources` | `azurerm`-specific setting, not applicable |
| D5 | General — Config file | Uses `terraform.tf` instead of `versions.tf` | Both names are valid; `terraform.tf` is this template's convention |
| D6 | General — Auth model | Uses OIDC via `POWER_PLATFORM_*` and `ARM_USE_OIDC` env vars | Power Platform provider reuses AzureRM OIDC conventions |
| D7 | TELEM1 — Telemetry | No telemetry beacon | Not applicable outside `Azure/` AVM registry namespace |

## References

- [Azure Verified Modules — Terraform Specs](https://azure.github.io/Azure-Verified-Modules/specs/terraform/)
- [Power Platform Terraform Provider](https://registry.terraform.io/providers/microsoft/power-platform/latest/docs)
- [Power Platform Custom Pipelines documentation](https://learn.microsoft.com/en-us/power-platform/alm/custom-pipelines)
