output "pipeline_id" {
  description = "The Dataverse record ID of the deployment pipeline."
  value       = module.deployment_pipeline.pipeline_id
}

output "deployment_stage_ids" {
  description = "The Dataverse deployment stage IDs keyed by environment key."
  value       = module.deployment_pipeline.deployment_stage_ids
}

output "sharing_enabled" {
  description = "Whether pipeline sharing is enabled (true when a security_group_id was provided)."
  value       = module.deployment_pipeline.pipeline_team_id != null
}
