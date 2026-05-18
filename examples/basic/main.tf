terraform {
  required_version = ">= 1.9, < 2.0"
  required_providers {
    powerplatform = {
      source  = "microsoft/power-platform"
      version = "~> 4.0"
    }
  }
}

module "deployment_pipeline" {
  source = "../.."

  dev_environment_key  = "dev"
  host_environment_id  = var.host_environment_id
  owner_system_user_id = var.owner_system_user_id
  pipeline_name        = var.pipeline_name
  pipelines_host_url   = var.pipelines_host_url

  environments = {
    dev = {
      id   = var.dev_environment_id
      name = "Development"
    }
    test = {
      id   = var.test_environment_id
      name = "Test"
    }
  }

  pipeline_stages = [
    {
      environment_key = "test"
    }
  ]
}
