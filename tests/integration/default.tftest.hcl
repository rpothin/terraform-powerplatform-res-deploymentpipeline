# Integration tests require a real Power Platform environment.
# Set the following environment variables before running:
#   POWER_PLATFORM_TENANT_ID
#   POWER_PLATFORM_CLIENT_ID
#   ARM_USE_OIDC=true (or POWER_PLATFORM_USE_OIDC=true)
#
# All module-specific inputs are injected at runtime via TF_VAR_* env vars:
#   TF_VAR_host_environment_id  - Pipelines Host environment ID (UUID)
#   TF_VAR_pipelines_host_url   - Pipelines Host Dataverse API URL
#   TF_VAR_environments         - JSON map of environments, e.g.:
#     '{"dev":{"id":"<uuid>","name":"tftest-dev"},"test":{"id":"<uuid>","name":"tftest-test"}}'
#   TF_VAR_security_group_id    - (Optional) Entra ID security group object ID (UUID);
#                                  when set, the module creates a team and shares the pipeline.

provider "powerplatform" {}

variables {
  dev_environment_key     = "dev"
  pipeline_name           = "tftest-deployment-pipeline"
  validation_wait_seconds = 60

  # Explicitly disable sharing so this test exercises only core pipeline lifecycle.
  # If teardown fails after a Dataverse team is created, the leftover group-backed team record
  # can cause azureactivedirectoryobjectid uniqueness collisions on subsequent CI runs.
  # Sharing is covered by unit tests.
  security_group_id = null

  pipeline_stages = [
    {
      environment_key = "test"
    }
  ]
}

run "creates_pipeline_environments_and_team" {
  command = apply

  assert {
    condition     = output.pipeline_id != ""
    error_message = "pipeline_id should not be empty after apply"
  }

  assert {
    condition     = length(output.deployment_environment_ids) == 2
    error_message = "Should have 2 deployment environment IDs"
  }

  assert {
    condition     = output.pipeline_team_id == null || length(output.pipeline_team_id) > 0
    error_message = "pipeline_team_id must be null (sharing disabled) or a non-empty UUID (sharing enabled)"
  }

  assert {
    condition     = length(output.deployment_stage_ids) == 1
    error_message = "Should have 1 deployment stage ID"
  }
}
