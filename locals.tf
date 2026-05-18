locals {
  deployment_environment_statecode  = var.lifecycle_state == "active" ? 0 : 1
  deployment_environment_statuscode = var.lifecycle_state == "active" ? 1 : 2

  pipeline_statecode  = var.lifecycle_state == "active" ? 0 : 1
  pipeline_statuscode = var.lifecycle_state == "active" ? 1 : 2

  pipelines_host_url_normalized = trimsuffix(var.pipelines_host_url, "/")
  pipelines_host_scope          = "${local.pipelines_host_url_normalized}/.default"

  sharing_enabled = var.enable_sharing && var.share_with_team_id != null

  stage_statecode  = var.lifecycle_state == "active" ? 0 : 1
  stage_statuscode = var.lifecycle_state == "active" ? 1 : 2

  stage_keys_depth_0 = length(var.pipeline_stages) > 0 ? [var.pipeline_stages[0].environment_key] : []
  stage_keys_depth_1 = length(var.pipeline_stages) > 1 ? [var.pipeline_stages[1].environment_key] : []
  stage_keys_depth_2 = length(var.pipeline_stages) > 2 ? [var.pipeline_stages[2].environment_key] : []
  stage_keys_depth_3 = length(var.pipeline_stages) > 3 ? [var.pipeline_stages[3].environment_key] : []
  stage_keys_depth_4 = length(var.pipeline_stages) > 4 ? [var.pipeline_stages[4].environment_key] : []
  stage_keys_depth_5 = length(var.pipeline_stages) > 5 ? [var.pipeline_stages[5].environment_key] : []
}
