# ─── Data sources: security role and root business unit lookup ──────────────── Test

data "powerplatform_data_records" "root_business_unit" {
  environment_id    = var.host_environment_id
  entity_collection = "businessunits"
  filter            = "parentbusinessunitid eq null"
  select            = ["businessunitid", "name"]
  top               = 1
}

data "powerplatform_security_roles" "host_environment" {
  # Only fetch when sharing is enabled; avoids unnecessary API calls and prevents
  # failures when the caller does not need the Deployment Pipeline User role.
  count = var.security_group_id != null ? 1 : 0

  environment_id   = var.host_environment_id
  business_unit_id = local.root_business_unit_id
}

# Idempotent: check whether a deploymentenvironment record already exists for each PP environment.
# A Power Platform System plugin bug (0x80073002) prevents deletion of deploymentstage and
# deploymentpipeline records, so terraform destroy/test teardown always fails partway through,
# leaving deploymentenvironment records orphaned. The next apply/test run would hit the Dataverse
# unique constraint on environmentid (0x80040265) if we tried to create duplicates.
data "powerplatform_data_records" "existing_deployment_environment" {
  for_each = var.environments

  environment_id    = var.host_environment_id
  entity_collection = "deploymentenvironments"
  filter            = "environmentid eq '${each.value.id}'"
  select            = ["deploymentenvironmentid", "statecode"]
  top               = 1
}

# ─── Cross-variable validation preconditions ────────────────────────────────

resource "terraform_data" "validate_dev_environment_key" {
  lifecycle {
    precondition {
      condition     = contains(keys(var.environments), var.dev_environment_key)
      error_message = "dev_environment_key \"${var.dev_environment_key}\" is not a key in the environments map. Valid keys: ${join(", ", sort(keys(var.environments)))}."
    }
  }
}

resource "terraform_data" "validate_stage_environment_keys" {
  lifecycle {
    precondition {
      condition = alltrue([
        for s in var.pipeline_stages :
        contains(keys(var.environments), s.environment_key)
      ])
      error_message = "One or more pipeline_stages reference an environment_key not found in the environments map."
    }

    precondition {
      condition = !contains([
        for s in var.pipeline_stages : s.environment_key
      ], var.dev_environment_key)
      error_message = "dev_environment_key \"${var.dev_environment_key}\" must not appear in pipeline_stages. The dev environment is not a deployment target stage."
    }
  }
}

resource "terraform_data" "validate_delegated_deployment" {
  for_each = {
    for idx, s in var.pipeline_stages :
    tostring(idx) => s
    if s.use_delegated_deployment == true
  }

  lifecycle {
    precondition {
      condition     = each.value.deployment_spn_client_id != null
      error_message = "pipeline_stages[${each.key}] has use_delegated_deployment = true but deployment_spn_client_id is not set."
    }
  }
}

resource "terraform_data" "validate_root_business_unit" {
  # Only validate when sharing is enabled; this data is only consumed by the team resource.
  count = var.security_group_id != null ? 1 : 0

  lifecycle {
    precondition {
      condition     = try(length(data.powerplatform_data_records.root_business_unit.rows), 0) == 1
      error_message = "Expected exactly one root business unit in the Pipelines Host environment, found ${try(length(data.powerplatform_data_records.root_business_unit.rows), 0)}."
    }
  }
}

resource "terraform_data" "validate_deployment_pipeline_role" {
  # Only validate when sharing is enabled; not needed when security_group_id is not set.
  count = var.security_group_id != null ? 1 : 0

  lifecycle {
    precondition {
      # Allow empty security_roles (mock/test context); in real environments, exactly one match is required.
      condition     = try(length(data.powerplatform_security_roles.host_environment[0].security_roles), 0) == 0 || length(local.deployment_pipeline_user_role_matches) == 1
      error_message = "Expected exactly one 'Deployment Pipeline User' security role in the Pipelines Host environment, found ${length(local.deployment_pipeline_user_role_matches)}. Ensure the Power Platform Pipelines solution is installed in the host environment."
    }
  }
}

resource "terraform_data" "security_group_identity" {
  count = var.security_group_id != null ? 1 : 0
  input = var.security_group_id
}

# ─── Step 1: Register deployment environments in the Pipelines Host ──────────

resource "powerplatform_data_record" "deployment_environment" {
  # Only create records that do not already exist in the Pipelines Host.
  for_each = {
    for k, v in var.environments : k => v
    if local.existing_deployment_environment_id[k] == null
  }

  environment_id     = var.host_environment_id
  table_logical_name = "deploymentenvironment"
  disable_on_destroy = var.disable_on_destroy

  columns = {
    environmentid = each.value.id
    # deploymentenvironment.environmenttype: 200000000 = Development, 200000001 = Target
    environmenttype = each.key == var.dev_environment_key ? 200000000 : 200000001
    name            = each.value.name
    statecode       = local.deployment_environment_statecode
    statuscode      = local.deployment_environment_statuscode
  }

  depends_on = [
    terraform_data.validate_dev_environment_key,
    terraform_data.validate_stage_environment_keys,
  ]

  lifecycle {
    ignore_changes = [columns]
  }
}

# ─── Step 1 (validation): Wait for async Pipelines Host environment validation

resource "terraform_data" "wait_for_validation" {
  for_each = var.environments

  triggers_replace = [
    local.resolved_deployment_environment_id[each.key],
    var.validation_wait_seconds,
  ]

  provisioner "local-exec" {
    command = "sleep ${var.validation_wait_seconds}"
  }

  depends_on = [powerplatform_data_record.deployment_environment]
}

data "powerplatform_data_records" "environment_validation" {
  for_each = var.environments

  environment_id    = var.host_environment_id
  entity_collection = "deploymentenvironments"
  filter            = "deploymentenvironmentid eq ${local.resolved_deployment_environment_id[each.key]}"
  select            = ["deploymentenvironmentid", "validationstatus"]

  depends_on = [terraform_data.wait_for_validation]
}

resource "terraform_data" "validation_assertion" {
  for_each = var.environments

  lifecycle {
    precondition {
      condition = (
        length(data.powerplatform_data_records.environment_validation[each.key].rows) > 0 &&
        tostring(data.powerplatform_data_records.environment_validation[each.key].rows[0]["validationstatus"]) == "200000001"
      )
      error_message = <<-EOT
Deployment environment '${each.key}' (${each.value.name}) failed Pipelines Host validation. Current status: ${length(data.powerplatform_data_records.environment_validation[each.key].rows) > 0 ? tostring(data.powerplatform_data_records.environment_validation[each.key].rows[0]["validationstatus"]) : "no records found"}. Expected status code 200000001 (Validated). Increase validation_wait_seconds if the host is slow to validate.
EOT
    }
  }
}

# ─── Step 2: Create the deployment pipeline record ───────────────────────────

resource "powerplatform_data_record" "pipeline" {
  environment_id     = var.host_environment_id
  table_logical_name = "deploymentpipeline"
  disable_on_destroy = var.disable_on_destroy

  columns = {
    description             = var.pipeline_description
    deploymenttype          = 0
    enableaideploymentnotes = var.enable_ai_deployment_notes
    enableredeployment      = var.enable_redeployment
    name                    = var.pipeline_name
    statecode               = local.pipeline_statecode
    statuscode              = local.pipeline_statuscode
  }

  depends_on = [terraform_data.validation_assertion]

  lifecycle {
    ignore_changes = [columns]
  }
}

# ─── Step 3a: Link the dev environment to the pipeline (OData $ref) ──────────

resource "powerplatform_rest" "dev_link" {
  create = {
    scope  = local.pipelines_host_scope
    method = "POST"
    url    = "${local.pipelines_host_url_normalized}/api/data/v9.0/deploymentpipelines(${powerplatform_data_record.pipeline.id})/deploymentpipeline_deploymentenvironment/$ref"
    body = jsonencode({
      "@odata.id" = "${local.pipelines_host_url_normalized}/api/data/v9.0/deploymentenvironments(${local.resolved_deployment_environment_id[var.dev_environment_key]})"
    })
    expected_http_status = [204]
  }

  destroy = {
    scope                = local.pipelines_host_scope
    method               = "DELETE"
    url                  = "${local.pipelines_host_url_normalized}/api/data/v9.0/deploymentpipelines(${powerplatform_data_record.pipeline.id})/deploymentpipeline_deploymentenvironment/$ref?$id=${local.pipelines_host_url_normalized}/api/data/v9.0/deploymentenvironments(${local.resolved_deployment_environment_id[var.dev_environment_key]})"
    body                 = ""
    expected_http_status = [204]
  }
}

# ─── Step 3b: Create deployment stages (linear chain, depth 0–5) ─────────────

resource "powerplatform_data_record" "stage_depth_0" {
  for_each = toset(local.stage_keys_depth_0)

  environment_id     = var.host_environment_id
  table_logical_name = "deploymentstage"
  disable_on_destroy = var.disable_on_destroy

  # delegateddeploymenttype is intentionally omitted. The provider serializes Terraform null as
  # an empty string "" for option-set/integer columns, which Dataverse rejects (Edm.Int32 cannot
  # convert ""). UI-created records also have this field absent (null server-side). Delegation
  # behavior is controlled entirely by isdelegateddeployment (boolean).
  columns = {
    deploymentpipelineid = {
      table_logical_name = "deploymentpipeline"
      data_record_id     = powerplatform_data_record.pipeline.id
    }
    description               = var.pipeline_stages[0].description
    isdelegateddeployment     = var.pipeline_stages[0].use_delegated_deployment
    issharingenabled          = var.pipeline_stages[0].is_sharing_enabled
    name                      = var.environments[each.key].name
    predeploymentsteprequired = var.pipeline_stages[0].require_predeployment_approval
    preexportsteprequired     = var.pipeline_stages[0].require_preexport_approval
    spnclientid               = var.pipeline_stages[0].deployment_spn_client_id
    statecode                 = local.stage_statecode
    statuscode                = local.stage_statuscode
    targetdeploymentenvironmentid = {
      table_logical_name = "deploymentenvironment"
      data_record_id     = local.resolved_deployment_environment_id[each.key]
    }
  }

  depends_on = [
    powerplatform_rest.dev_link,
    terraform_data.validate_delegated_deployment,
  ]

  lifecycle {
    ignore_changes = [columns]
  }
}

resource "powerplatform_data_record" "stage_depth_1" {
  for_each = toset(local.stage_keys_depth_1)

  environment_id     = var.host_environment_id
  table_logical_name = "deploymentstage"
  disable_on_destroy = var.disable_on_destroy

  columns = {
    deploymentpipelineid = {
      table_logical_name = "deploymentpipeline"
      data_record_id     = powerplatform_data_record.pipeline.id
    }
    description               = var.pipeline_stages[1].description
    isdelegateddeployment     = var.pipeline_stages[1].use_delegated_deployment
    issharingenabled          = var.pipeline_stages[1].is_sharing_enabled
    name                      = var.environments[each.key].name
    predeploymentsteprequired = var.pipeline_stages[1].require_predeployment_approval
    preexportsteprequired     = false
    previousdeploymentstageid = {
      table_logical_name = "deploymentstage"
      data_record_id     = one(values(powerplatform_data_record.stage_depth_0)).id
    }
    spnclientid = var.pipeline_stages[1].deployment_spn_client_id
    statecode   = local.stage_statecode
    statuscode  = local.stage_statuscode
    targetdeploymentenvironmentid = {
      table_logical_name = "deploymentenvironment"
      data_record_id     = local.resolved_deployment_environment_id[each.key]
    }
  }

  lifecycle {
    ignore_changes = [columns]
  }
}

resource "powerplatform_data_record" "stage_depth_2" {
  for_each = toset(local.stage_keys_depth_2)

  environment_id     = var.host_environment_id
  table_logical_name = "deploymentstage"
  disable_on_destroy = var.disable_on_destroy

  columns = {
    deploymentpipelineid = {
      table_logical_name = "deploymentpipeline"
      data_record_id     = powerplatform_data_record.pipeline.id
    }
    description               = var.pipeline_stages[2].description
    isdelegateddeployment     = var.pipeline_stages[2].use_delegated_deployment
    issharingenabled          = var.pipeline_stages[2].is_sharing_enabled
    name                      = var.environments[each.key].name
    predeploymentsteprequired = var.pipeline_stages[2].require_predeployment_approval
    preexportsteprequired     = false
    previousdeploymentstageid = {
      table_logical_name = "deploymentstage"
      data_record_id     = one(values(powerplatform_data_record.stage_depth_1)).id
    }
    spnclientid = var.pipeline_stages[2].deployment_spn_client_id
    statecode   = local.stage_statecode
    statuscode  = local.stage_statuscode
    targetdeploymentenvironmentid = {
      table_logical_name = "deploymentenvironment"
      data_record_id     = local.resolved_deployment_environment_id[each.key]
    }
  }

  lifecycle {
    ignore_changes = [columns]
  }
}

resource "powerplatform_data_record" "stage_depth_3" {
  for_each = toset(local.stage_keys_depth_3)

  environment_id     = var.host_environment_id
  table_logical_name = "deploymentstage"
  disable_on_destroy = var.disable_on_destroy

  columns = {
    deploymentpipelineid = {
      table_logical_name = "deploymentpipeline"
      data_record_id     = powerplatform_data_record.pipeline.id
    }
    description               = var.pipeline_stages[3].description
    isdelegateddeployment     = var.pipeline_stages[3].use_delegated_deployment
    issharingenabled          = var.pipeline_stages[3].is_sharing_enabled
    name                      = var.environments[each.key].name
    predeploymentsteprequired = var.pipeline_stages[3].require_predeployment_approval
    preexportsteprequired     = false
    previousdeploymentstageid = {
      table_logical_name = "deploymentstage"
      data_record_id     = one(values(powerplatform_data_record.stage_depth_2)).id
    }
    spnclientid = var.pipeline_stages[3].deployment_spn_client_id
    statecode   = local.stage_statecode
    statuscode  = local.stage_statuscode
    targetdeploymentenvironmentid = {
      table_logical_name = "deploymentenvironment"
      data_record_id     = local.resolved_deployment_environment_id[each.key]
    }
  }

  lifecycle {
    ignore_changes = [columns]
  }
}

resource "powerplatform_data_record" "stage_depth_4" {
  for_each = toset(local.stage_keys_depth_4)

  environment_id     = var.host_environment_id
  table_logical_name = "deploymentstage"
  disable_on_destroy = var.disable_on_destroy

  columns = {
    deploymentpipelineid = {
      table_logical_name = "deploymentpipeline"
      data_record_id     = powerplatform_data_record.pipeline.id
    }
    description               = var.pipeline_stages[4].description
    isdelegateddeployment     = var.pipeline_stages[4].use_delegated_deployment
    issharingenabled          = var.pipeline_stages[4].is_sharing_enabled
    name                      = var.environments[each.key].name
    predeploymentsteprequired = var.pipeline_stages[4].require_predeployment_approval
    preexportsteprequired     = false
    previousdeploymentstageid = {
      table_logical_name = "deploymentstage"
      data_record_id     = one(values(powerplatform_data_record.stage_depth_3)).id
    }
    spnclientid = var.pipeline_stages[4].deployment_spn_client_id
    statecode   = local.stage_statecode
    statuscode  = local.stage_statuscode
    targetdeploymentenvironmentid = {
      table_logical_name = "deploymentenvironment"
      data_record_id     = local.resolved_deployment_environment_id[each.key]
    }
  }

  lifecycle {
    ignore_changes = [columns]
  }
}

resource "powerplatform_data_record" "stage_depth_5" {
  for_each = toset(local.stage_keys_depth_5)

  environment_id     = var.host_environment_id
  table_logical_name = "deploymentstage"
  disable_on_destroy = var.disable_on_destroy

  columns = {
    deploymentpipelineid = {
      table_logical_name = "deploymentpipeline"
      data_record_id     = powerplatform_data_record.pipeline.id
    }
    description               = var.pipeline_stages[5].description
    isdelegateddeployment     = var.pipeline_stages[5].use_delegated_deployment
    issharingenabled          = var.pipeline_stages[5].is_sharing_enabled
    name                      = var.environments[each.key].name
    predeploymentsteprequired = var.pipeline_stages[5].require_predeployment_approval
    preexportsteprequired     = false
    previousdeploymentstageid = {
      table_logical_name = "deploymentstage"
      data_record_id     = one(values(powerplatform_data_record.stage_depth_4)).id
    }
    spnclientid = var.pipeline_stages[5].deployment_spn_client_id
    statecode   = local.stage_statecode
    statuscode  = local.stage_statuscode
    targetdeploymentenvironmentid = {
      table_logical_name = "deploymentenvironment"
      data_record_id     = local.resolved_deployment_environment_id[each.key]
    }
  }

  lifecycle {
    ignore_changes = [columns]
  }
}

# ─── Step 3c: Create the pipeline access team and assign security role ────────

resource "powerplatform_data_record" "pipeline_team" {
  # Only created when an Entra ID security group is provided.
  count = var.security_group_id != null ? 1 : 0

  environment_id     = var.host_environment_id
  table_logical_name = "team"
  disable_on_destroy = var.disable_on_destroy

  columns = {
    name                         = "${var.pipeline_name} - Deployment Pipeline Users"
    teamtype                     = 2
    membershiptype               = 0
    azureactivedirectoryobjectid = var.security_group_id

    businessunitid = {
      table_logical_name = "businessunit"
      data_record_id     = local.root_business_unit_id
    }

    teamroles_association = tolist([{
      table_logical_name = "role"
      data_record_id     = local.deployment_pipeline_user_role_id
    }])
  }

  depends_on = [
    terraform_data.validate_root_business_unit,
    terraform_data.validate_deployment_pipeline_role,
  ]

  lifecycle {
    ignore_changes       = [columns]
    replace_triggered_by = [terraform_data.security_group_identity[0]]
  }
}

# ─── Step 4: Share the pipeline with the pipeline access team ─────────────────

resource "powerplatform_rest" "pipeline_sharing" {
  # Only created when an Entra ID security group is provided.
  count = var.security_group_id != null ? 1 : 0

  create = {
    scope  = local.pipelines_host_scope
    method = "POST"
    url    = "${local.pipelines_host_url_normalized}/api/data/v9.0/GrantAccess"
    body = jsonencode({
      Target = {
        deploymentpipelineid = powerplatform_data_record.pipeline.id
        "@odata.type"        = "Microsoft.Dynamics.CRM.deploymentpipeline"
      }
      PrincipalAccess = {
        Principal = {
          teamid        = powerplatform_data_record.pipeline_team[0].id
          "@odata.type" = "Microsoft.Dynamics.CRM.team"
        }
        AccessMask = "ReadAccess"
      }
    })
    expected_http_status = [200, 204]
  }

  destroy = {
    scope  = local.pipelines_host_scope
    method = "POST"
    url    = "${local.pipelines_host_url_normalized}/api/data/v9.0/RevokeAccess"
    body = jsonencode({
      Target = {
        deploymentpipelineid = powerplatform_data_record.pipeline.id
        "@odata.type"        = "Microsoft.Dynamics.CRM.deploymentpipeline"
      }
      Revokee = {
        teamid        = powerplatform_data_record.pipeline_team[0].id
        "@odata.type" = "Microsoft.Dynamics.CRM.team"
      }
    })
    expected_http_status = [200, 204]
  }
}
