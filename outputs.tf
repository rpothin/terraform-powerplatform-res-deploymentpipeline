output "deployment_environment_ids" {
  description = "A map from environment key to the Dataverse `deploymentenvironment` record ID for each registered environment."
  value       = local.resolved_deployment_environment_id
}

output "deployment_stage_ids" {
  description = "A map from environment key to the Dataverse `deploymentstage` record ID for each pipeline stage."
  value = merge(
    { for k, r in powerplatform_data_record.stage_depth_0 : k => r.id },
    { for k, r in powerplatform_data_record.stage_depth_1 : k => r.id },
    { for k, r in powerplatform_data_record.stage_depth_2 : k => r.id },
    { for k, r in powerplatform_data_record.stage_depth_3 : k => r.id },
    { for k, r in powerplatform_data_record.stage_depth_4 : k => r.id },
    { for k, r in powerplatform_data_record.stage_depth_5 : k => r.id },
  )
}

output "pipeline_id" {
  description = "The Dataverse record ID of the deployment pipeline."
  value       = powerplatform_data_record.pipeline.id
}

output "pipeline_name" {
  description = "The display name of the deployment pipeline."
  value       = var.pipeline_name
}

output "pipeline_team_id" {
  description = "The Dataverse record ID of the team created for the Entra ID security group."
  value       = powerplatform_data_record.pipeline_team.id
}
