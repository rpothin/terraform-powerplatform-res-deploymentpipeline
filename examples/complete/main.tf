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
  source  = "rpothin/deploymentpipeline/powerplatform"
  version = "0.1.0"

  dev_environment_key = "dev"
  host_environment_id = var.host_environment_id
  pipeline_name       = var.pipeline_name
  pipelines_host_url  = var.pipelines_host_url

  environments = {
    dev = {
      id   = var.dev_environment_id
      name = "Development"
    }
    test = {
      id   = var.test_environment_id
      name = "Test"
    }
    staging = {
      id   = var.staging_environment_id
      name = "Staging"
    }
    prod = {
      id   = var.prod_environment_id
      name = "Production"
    }
  }

  pipeline_stages = [
    {
      environment_key = "test"
    },
    {
      environment_key = "staging"
    },
    {
      environment_key                = "prod"
      require_predeployment_approval = true
    }
  ]

  enable_ai_deployment_notes = true
  enable_redeployment        = true
  pipeline_description       = var.pipeline_description
  security_group_id          = var.security_group_id
  validation_wait_seconds    = 30
}
