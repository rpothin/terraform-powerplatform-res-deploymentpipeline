mock_provider "powerplatform" {
  mock_data "powerplatform_data_records" {
    defaults = {
      rows = [
        {
          businessunitid   = "00000000-0000-0000-0000-000000000099"
          validationstatus = "200000001"
        }
      ]
    }
  }
}

variables {
  dev_environment_key = "dev"
  host_environment_id = "11111111-1111-1111-1111-111111111111"
  pipeline_name       = "My Pipeline"
  pipelines_host_url  = "https://org.crm.dynamics.com"

  environments = {
    dev = {
      id   = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"
      name = "Development"
    }
    test = {
      id   = "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"
      name = "Test"
    }
  }

  pipeline_stages = [
    {
      environment_key = "test"
    }
  ]
}

run "rejects_invalid_host_environment_id" {
  command = plan

  variables {
    host_environment_id = "not-a-uuid"
  }

  expect_failures = [var.host_environment_id]
}

run "rejects_environment_with_invalid_uuid" {
  command = plan

  variables {
    environments = {
      dev = {
        id   = "invalid"
        name = "Development"
      }
      test = {
        id   = "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"
        name = "Test"
      }
    }
  }

  expect_failures = [var.environments]
}

run "rejects_empty_pipeline_name" {
  command = plan

  variables {
    pipeline_name = ""
  }

  expect_failures = [var.pipeline_name]
}

run "rejects_pipeline_name_too_long" {
  command = plan

  variables {
    pipeline_name = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
  }

  expect_failures = [var.pipeline_name]
}

run "rejects_pipeline_description_too_long" {
  command = plan

  variables {
    pipeline_description = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
  }

  expect_failures = [var.pipeline_description]
}

run "rejects_invalid_pipelines_host_url" {
  command = plan

  variables {
    pipelines_host_url = "http://insecure.com"
  }

  expect_failures = [var.pipelines_host_url]
}

run "rejects_invalid_lifecycle_state" {
  command = plan

  variables {
    lifecycle_state = "pending"
  }

  expect_failures = [var.lifecycle_state]
}

run "rejects_invalid_security_group_id" {
  command = plan

  variables {
    security_group_id = "not-a-uuid"
  }

  expect_failures = [var.security_group_id]
}

run "accepts_sharing_disabled" {
  command = plan

  variables {
    security_group_id = null
  }
}

run "accepts_sharing_enabled_with_valid_uuid" {
  command = plan

  variables {
    security_group_id = "cccccccc-cccc-cccc-cccc-cccccccccccc"
  }
}

run "rejects_invalid_validation_wait_seconds" {
  command = plan

  variables {
    validation_wait_seconds = -1
  }

  expect_failures = [var.validation_wait_seconds]
}

run "rejects_validation_wait_seconds_too_high" {
  command = plan

  variables {
    validation_wait_seconds = 601
  }

  expect_failures = [var.validation_wait_seconds]
}

run "rejects_too_many_stages" {
  command = plan

  variables {
    environments = {
      dev = {
        id   = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"
        name = "Development"
      }
      s1 = {
        id   = "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"
        name = "S1"
      }
      s2 = {
        id   = "cccccccc-cccc-cccc-cccc-cccccccccccc"
        name = "S2"
      }
      s3 = {
        id   = "dddddddd-dddd-dddd-dddd-dddddddddddd"
        name = "S3"
      }
      s4 = {
        id   = "eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee"
        name = "S4"
      }
      s5 = {
        id   = "ffffffff-ffff-ffff-ffff-ffffffffffff"
        name = "S5"
      }
      s6 = {
        id   = "12121212-1212-1212-1212-121212121212"
        name = "S6"
      }
      s7 = {
        id   = "34343434-3434-3434-3434-343434343434"
        name = "S7"
      }
    }

    pipeline_stages = [
      { environment_key = "s1" },
      { environment_key = "s2" },
      { environment_key = "s3" },
      { environment_key = "s4" },
      { environment_key = "s5" },
      { environment_key = "s6" },
      { environment_key = "s7" },
    ]
  }

  expect_failures = [var.pipeline_stages]
}

run "rejects_empty_environments" {
  command = plan

  variables {
    environments = {
      dev = {
        id   = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"
        name = "Development"
      }
    }
  }

  expect_failures = [var.environments]
}

run "rejects_duplicate_stage_keys" {
  command = plan

  variables {
    environments = {
      dev = {
        id   = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"
        name = "Development"
      }
      test = {
        id   = "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"
        name = "Test"
      }
      prod = {
        id   = "cccccccc-cccc-cccc-cccc-cccccccccccc"
        name = "Production"
      }
    }

    pipeline_stages = [
      { environment_key = "test" },
      { environment_key = "test" },
    ]
  }

  expect_failures = [var.pipeline_stages]
}

run "accepts_valid_minimal_configuration" {
  command = plan
}

run "all_environments_have_registration_ids" {
  command = plan

  # Regression: for_each = var.environments (not a conditional expression) ensures
  # deployment_environment_ids always contains one entry per environment, including
  # on a first apply when environment IDs are unknown at plan time (day-1 scenario).
  assert {
    condition     = length(output.deployment_environment_ids) == length(var.environments)
    error_message = "deployment_environment_ids must contain one entry per environment in var.environments."
  }
}

run "rejects_dev_key_not_in_environments" {
  command = plan

  variables {
    dev_environment_key = "missing"
  }

  expect_failures = [terraform_data.validate_dev_environment_key]
}

run "rejects_stage_key_not_in_environments" {
  command = plan

  variables {
    pipeline_stages = [
      {
        environment_key = "missing_env"
      }
    ]
  }

  expect_failures = [terraform_data.validate_stage_environment_keys]
}

run "rejects_dev_key_used_as_stage" {
  command = plan

  variables {
    dev_environment_key = "test"
  }

  expect_failures = [terraform_data.validate_stage_environment_keys]
}

run "rejects_invalid_deployment_spn_client_id" {
  command = plan

  variables {
    environments = {
      dev = {
        id   = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"
        name = "Development"
      }
      test = {
        id   = "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"
        name = "Test"
      }
    }

    pipeline_stages = [
      {
        environment_key          = "test"
        deployment_spn_client_id = "not-a-uuid"
      }
    ]
  }

  expect_failures = [var.pipeline_stages]
}
