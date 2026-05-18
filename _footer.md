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
