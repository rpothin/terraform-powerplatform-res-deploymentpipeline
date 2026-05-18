# Integration tests require a real Power Platform environment.
# Set the following environment variables before running:
#   POWER_PLATFORM_TENANT_ID
#   POWER_PLATFORM_CLIENT_ID
#   ARM_USE_OIDC=true

provider "powerplatform" {}

variables {
  dev_environment_key     = "dev"
  pipeline_name           = "tftest-deployment-pipeline"
  validation_wait_seconds = 60

  # Override these with real environment IDs via TF_VAR_ environment variables
  host_environment_id  = "00000000-0000-0000-0000-000000000000"
  owner_system_user_id = "00000000-0000-0000-0000-000000000000"
  pipelines_host_url   = "https://placeholder.crm.dynamics.com"

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

run "creates_pipeline_and_environments" {
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
    condition     = contains(keys(output.deployment_environment_ids), "dev")
    error_message = "deployment_environment_ids should contain key 'dev'"
  }

  assert {
    condition     = contains(keys(output.deployment_environment_ids), "test")
    error_message = "deployment_environment_ids should contain key 'test'"
  }

  assert {
    condition     = length(output.deployment_stage_ids) == 1
    error_message = "Should have 1 deployment stage ID"
  }

  assert {
    condition     = output.sharing_enabled == false
    error_message = "sharing_enabled should be false when enable_sharing is not set"
  }
}
