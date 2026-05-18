# Integration tests require a real Power Platform environment.
# Set the following environment variables before running:
#   POWER_PLATFORM_TENANT_ID
#   POWER_PLATFORM_CLIENT_ID
#   ARM_USE_OIDC=true
#   TF_VAR_host_environment_id=<real-host-env-id>
#   TF_VAR_owner_system_user_id=<real-user-id>
#   TF_VAR_pipelines_host_url=<real-url>
#   TF_VAR_security_group_id=<real-entra-group-id>

provider "powerplatform" {}

variables {
  dev_environment_key     = "dev"
  pipeline_name           = "tftest-deployment-pipeline"
  validation_wait_seconds = 60

  host_environment_id  = "00000000-0000-0000-0000-000000000000"
  owner_system_user_id = "00000000-0000-0000-0000-000000000000"
  pipelines_host_url   = "https://placeholder.crm.dynamics.com"
  security_group_id    = "00000000-0000-0000-0000-000000000000"

  environments = {
    dev = {
      id   = "00000000-0000-0000-0000-000000000001"
      name = "tftest-dev"
    }
    test = {
      id   = "00000000-0000-0000-0000-000000000002"
      name = "tftest-test"
    }
  }

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
    condition     = output.pipeline_team_id != ""
    error_message = "pipeline_team_id should not be empty after apply"
  }

  assert {
    condition     = length(output.deployment_stage_ids) == 1
    error_message = "Should have 1 deployment stage ID"
  }
}
