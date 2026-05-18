output "pipeline_id" {
  description = "The Dataverse record ID of the deployment pipeline."
  value       = module.deployment_pipeline.pipeline_id
}

output "deployment_stage_ids" {
  description = "The Dataverse deployment stage IDs keyed by environment key."
  value       = module.deployment_pipeline.deployment_stage_ids
}

output "sharing_enabled" {
  description = "Whether the pipeline sharing configuration is enabled."
  value       = module.deployment_pipeline.sharing_enabled
}
