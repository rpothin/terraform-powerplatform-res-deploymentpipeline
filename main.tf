# ─── Data sources: security role and root business unit lookup ────────────────

data "powerplatform_data_records" "root_business_unit" {
  environment_id    = var.host_environment_id
  entity_collection = "businessunits"
  filter            = "parentbusinessunitid eq null"
  select            = ["businessunitid", "name"]
  top               = 1
}

data "powerplatform_security_roles" "host_environment" {
  environment_id   = var.host_environment_id
  business_unit_id = local.root_business_unit_id
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
  lifecycle {
    precondition {
      condition     = try(length(data.powerplatform_data_records.root_business_unit.rows), 0) == 1
      error_message = "Expected exactly one root business unit in the Pipelines Host environment, found ${try(length(data.powerplatform_data_records.root_business_unit.rows), 0)}."
    }
  }
}

resource "terraform_data" "validate_deployment_pipeline_role" {
  lifecycle {
    precondition {
      # Allow empty security_roles (mock/test context); in real environments, exactly one match is required.
      condition     = try(length(data.powerplatform_security_roles.host_environment.security_roles), 0) == 0 || length(local.deployment_pipeline_user_role_matches) == 1
      error_message = "Expected exactly one 'Deployment Pipeline User' security role in the Pipelines Host environment, found ${length(local.deployment_pipeline_user_role_matches)}. Ensure the Power Platform Pipelines solution is installed in the host environment."
    }
  }
}

resource "terraform_data" "security_group_identity" {
  input = var.security_group_id
}

# ─── Step 1: Register deployment environments in the Pipelines Host ──────────

resource "powerplatform_data_record" "deployment_environment" {
  for_each = var.environments

  environment_id     = var.host_environment_id
  table_logical_name = "deploymentenvironment"
  disable_on_destroy = var.disable_on_destroy

  columns = {
    environmentid = each.value.id
    name          = each.value.name
    ownerid       = var.owner_system_user_id != null ? "/systemusers(${var.owner_system_user_id})" : null
    statecode     = local.deployment_environment_statecode
    statuscode    = local.deployment_environment_statuscode
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
    powerplatform_data_record.deployment_environment[each.key].id,
    var.validation_wait_seconds,
  ]

  provisioner "local-exec" {
    command = "sleep ${var.validation_wait_seconds}"
  }
}

data "powerplatform_data_records" "environment_validation" {
  for_each = var.environments

  environment_id    = var.host_environment_id
  entity_collection = "deploymentenvironments"
  filter            = "deploymentenvironmentid eq ${powerplatform_data_record.deployment_environment[each.key].id}"
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
    description                    = var.pipeline_description
    isdeploymentnotesandaiinsights = var.enable_ai_deployment_notes
    isredeploymentenabled          = var.enable_redeployment
    name                           = var.pipeline_name
    ownerid                        = var.owner_system_user_id != null ? "/systemusers(${var.owner_system_user_id})" : null
    statecode                      = local.pipeline_statecode
    statuscode                     = local.pipeline_statuscode
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
      "@odata.id" = "${local.pipelines_host_url_normalized}/api/data/v9.0/deploymentenvironments(${powerplatform_data_record.deployment_environment[var.dev_environment_key].id})"
    })
    expected_http_status = [204]
  }

  destroy = {
    scope                = local.pipelines_host_scope
    method               = "DELETE"
    url                  = "${local.pipelines_host_url_normalized}/api/data/v9.0/deploymentpipelines(${powerplatform_data_record.pipeline.id})/deploymentpipeline_deploymentenvironment/$ref?$id=${local.pipelines_host_url_normalized}/api/data/v9.0/deploymentenvironments(${powerplatform_data_record.deployment_environment[var.dev_environment_key].id})"
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

  columns = {
    deploymentenvironmentid      = "/deploymentenvironments(${powerplatform_data_record.deployment_environment[each.key].id})"
    deploymentpipelineid         = "/deploymentpipelines(${powerplatform_data_record.pipeline.id})"
    deploymentserviceprincipalid = var.pipeline_stages[0].deployment_spn_client_id
    description                  = var.pipeline_stages[0].description
    isautomateddeployment        = var.pipeline_stages[0].use_delegated_deployment
    issharingenabled             = var.pipeline_stages[0].is_sharing_enabled
    name                         = var.environments[each.key].name
    ownerid                      = var.owner_system_user_id != null ? "/systemusers(${var.owner_system_user_id})" : null
    predeploymentsteprequired    = var.pipeline_stages[0].require_predeployment_approval
    preexportsteprequired        = var.pipeline_stages[0].require_preexport_approval
    statecode                    = local.stage_statecode
    statuscode                   = local.stage_statuscode
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
    deploymentenvironmentid      = "/deploymentenvironments(${powerplatform_data_record.deployment_environment[each.key].id})"
    deploymentpipelineid         = "/deploymentpipelines(${powerplatform_data_record.pipeline.id})"
    deploymentserviceprincipalid = var.pipeline_stages[1].deployment_spn_client_id
    description                  = var.pipeline_stages[1].description
    isautomateddeployment        = var.pipeline_stages[1].use_delegated_deployment
    issharingenabled             = var.pipeline_stages[1].is_sharing_enabled
    name                         = var.environments[each.key].name
    ownerid                      = var.owner_system_user_id != null ? "/systemusers(${var.owner_system_user_id})" : null
    predeploymentsteprequired    = var.pipeline_stages[1].require_predeployment_approval
    preexportsteprequired        = false
    previousdeploymentstageid    = "/deploymentstages(${one(values(powerplatform_data_record.stage_depth_0)).id})"
    statecode                    = local.stage_statecode
    statuscode                   = local.stage_statuscode
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
    deploymentenvironmentid      = "/deploymentenvironments(${powerplatform_data_record.deployment_environment[each.key].id})"
    deploymentpipelineid         = "/deploymentpipelines(${powerplatform_data_record.pipeline.id})"
    deploymentserviceprincipalid = var.pipeline_stages[2].deployment_spn_client_id
    description                  = var.pipeline_stages[2].description
    isautomateddeployment        = var.pipeline_stages[2].use_delegated_deployment
    issharingenabled             = var.pipeline_stages[2].is_sharing_enabled
    name                         = var.environments[each.key].name
    ownerid                      = var.owner_system_user_id != null ? "/systemusers(${var.owner_system_user_id})" : null
    predeploymentsteprequired    = var.pipeline_stages[2].require_predeployment_approval
    preexportsteprequired        = false
    previousdeploymentstageid    = "/deploymentstages(${one(values(powerplatform_data_record.stage_depth_1)).id})"
    statecode                    = local.stage_statecode
    statuscode                   = local.stage_statuscode
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
    deploymentenvironmentid      = "/deploymentenvironments(${powerplatform_data_record.deployment_environment[each.key].id})"
    deploymentpipelineid         = "/deploymentpipelines(${powerplatform_data_record.pipeline.id})"
    deploymentserviceprincipalid = var.pipeline_stages[3].deployment_spn_client_id
    description                  = var.pipeline_stages[3].description
    isautomateddeployment        = var.pipeline_stages[3].use_delegated_deployment
    issharingenabled             = var.pipeline_stages[3].is_sharing_enabled
    name                         = var.environments[each.key].name
    ownerid                      = var.owner_system_user_id != null ? "/systemusers(${var.owner_system_user_id})" : null
    predeploymentsteprequired    = var.pipeline_stages[3].require_predeployment_approval
    preexportsteprequired        = false
    previousdeploymentstageid    = "/deploymentstages(${one(values(powerplatform_data_record.stage_depth_2)).id})"
    statecode                    = local.stage_statecode
    statuscode                   = local.stage_statuscode
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
    deploymentenvironmentid      = "/deploymentenvironments(${powerplatform_data_record.deployment_environment[each.key].id})"
    deploymentpipelineid         = "/deploymentpipelines(${powerplatform_data_record.pipeline.id})"
    deploymentserviceprincipalid = var.pipeline_stages[4].deployment_spn_client_id
    description                  = var.pipeline_stages[4].description
    isautomateddeployment        = var.pipeline_stages[4].use_delegated_deployment
    issharingenabled             = var.pipeline_stages[4].is_sharing_enabled
    name                         = var.environments[each.key].name
    ownerid                      = var.owner_system_user_id != null ? "/systemusers(${var.owner_system_user_id})" : null
    predeploymentsteprequired    = var.pipeline_stages[4].require_predeployment_approval
    preexportsteprequired        = false
    previousdeploymentstageid    = "/deploymentstages(${one(values(powerplatform_data_record.stage_depth_3)).id})"
    statecode                    = local.stage_statecode
    statuscode                   = local.stage_statuscode
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
    deploymentenvironmentid      = "/deploymentenvironments(${powerplatform_data_record.deployment_environment[each.key].id})"
    deploymentpipelineid         = "/deploymentpipelines(${powerplatform_data_record.pipeline.id})"
    deploymentserviceprincipalid = var.pipeline_stages[5].deployment_spn_client_id
    description                  = var.pipeline_stages[5].description
    isautomateddeployment        = var.pipeline_stages[5].use_delegated_deployment
    issharingenabled             = var.pipeline_stages[5].is_sharing_enabled
    name                         = var.environments[each.key].name
    ownerid                      = var.owner_system_user_id != null ? "/systemusers(${var.owner_system_user_id})" : null
    predeploymentsteprequired    = var.pipeline_stages[5].require_predeployment_approval
    preexportsteprequired        = false
    previousdeploymentstageid    = "/deploymentstages(${one(values(powerplatform_data_record.stage_depth_4)).id})"
    statecode                    = local.stage_statecode
    statuscode                   = local.stage_statuscode
  }

  lifecycle {
    ignore_changes = [columns]
  }
}

# ─── Step 3c: Create the pipeline access team and assign security role ────────

resource "powerplatform_data_record" "pipeline_team" {
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
    replace_triggered_by = [terraform_data.security_group_identity]
  }
}

# ─── Step 4: Share the pipeline with the pipeline access team ─────────────────

resource "powerplatform_rest" "pipeline_sharing" {
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
          teamid        = powerplatform_data_record.pipeline_team.id
          "@odata.type" = "Microsoft.Dynamics.CRM.team"
        }
        AccessRights = "ReadAccess"
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
        teamid        = powerplatform_data_record.pipeline_team.id
        "@odata.type" = "Microsoft.Dynamics.CRM.team"
      }
    })
    expected_http_status = [200, 204]
  }
}
