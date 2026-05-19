locals {
  deployment_environment_statecode  = var.lifecycle_state == "active" ? 0 : 1
  deployment_environment_statuscode = var.lifecycle_state == "active" ? 1 : 2

  deployment_pipeline_user_role_matches = try([
    for role in data.powerplatform_security_roles.host_environment.security_roles :
    role.role_id
    if role.name == "Deployment Pipeline User"
  ], [])

  deployment_pipeline_user_role_id = length(local.deployment_pipeline_user_role_matches) == 1 ? local.deployment_pipeline_user_role_matches[0] : null

  pipeline_statecode  = var.lifecycle_state == "active" ? 0 : 1
  pipeline_statuscode = var.lifecycle_state == "active" ? 1 : 2

  pipelines_host_url_normalized = trimsuffix(var.pipelines_host_url, "/")
  pipelines_host_scope          = "${local.pipelines_host_url_normalized}/.default"

  root_business_unit_id = try(tostring(data.powerplatform_data_records.root_business_unit.rows[0]["businessunitid"]), null)

  # Idempotent: for each environment, the ID of an already-registered deploymentenvironment
  # record (null when none exists and a new record must be created).
  existing_deployment_environment_id = {
    for k, d in data.powerplatform_data_records.existing_deployment_environment :
    k => length(d.rows) > 0 ? try(tostring(d.rows[0]["deploymentenvironmentid"]), null) : null
  }

  # Resolved IDs that are valid regardless of whether the record was just created or pre-existed.
  resolved_deployment_environment_id = {
    for k in keys(var.environments) :
    k => local.existing_deployment_environment_id[k] != null ?
    local.existing_deployment_environment_id[k] :
    try(powerplatform_data_record.deployment_environment[k].id, null)
  }

  stage_statecode  = var.lifecycle_state == "active" ? 0 : 1
  stage_statuscode = var.lifecycle_state == "active" ? 1 : 2

  stage_keys_depth_0 = length(var.pipeline_stages) > 0 ? [var.pipeline_stages[0].environment_key] : []
  stage_keys_depth_1 = length(var.pipeline_stages) > 1 ? [var.pipeline_stages[1].environment_key] : []
  stage_keys_depth_2 = length(var.pipeline_stages) > 2 ? [var.pipeline_stages[2].environment_key] : []
  stage_keys_depth_3 = length(var.pipeline_stages) > 3 ? [var.pipeline_stages[3].environment_key] : []
  stage_keys_depth_4 = length(var.pipeline_stages) > 4 ? [var.pipeline_stages[4].environment_key] : []
  stage_keys_depth_5 = length(var.pipeline_stages) > 5 ? [var.pipeline_stages[5].environment_key] : []
}
