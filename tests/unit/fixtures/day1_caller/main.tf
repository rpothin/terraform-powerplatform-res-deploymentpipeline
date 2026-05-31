# Fixture: Simulates a day-1 caller where environment IDs are unknown at plan time.
#
# terraform_data.fake_env_id[*].id is (known after apply) during plan,
# so var.environments.*.id inside the module under test is unknown at plan time.
# This exercises the exact scenario that previously triggered "Invalid for_each argument".

resource "terraform_data" "fake_env_id" {
  for_each = toset(["dev", "test"])
}

module "subject" {
  source = "../../../../"

  dev_environment_key = "dev"
  host_environment_id = "11111111-1111-1111-1111-111111111111"
  pipeline_name       = "Day-1 Fixture Pipeline"
  pipelines_host_url  = "https://org00000000.crm.dynamics.com"

  environments = {
    dev = {
      id   = terraform_data.fake_env_id["dev"].id
      name = "Development"
    }
    test = {
      id   = terraform_data.fake_env_id["test"].id
      name = "Test"
    }
  }

  pipeline_stages = [
    { environment_key = "test" }
  ]
}
