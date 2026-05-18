variable "dev_environment_id" {
  description = "The Power Platform environment ID of the development environment."
  type        = string
}

variable "enable_sharing" {
  description = "Whether to share the pipeline with a Dataverse team."
  type        = bool
  default     = false
}

variable "host_environment_id" {
  description = "The Power Platform environment ID of the Pipelines Host environment."
  type        = string
}

variable "owner_system_user_id" {
  description = "The Dataverse system user ID that will own the pipeline records."
  type        = string
}

variable "pipeline_description" {
  description = "An optional description for the deployment pipeline."
  type        = string
  default     = null
}

variable "pipeline_name" {
  description = "The display name of the deployment pipeline."
  type        = string
}

variable "pipelines_host_url" {
  description = "The Dataverse API URL for the Pipelines Host environment."
  type        = string
}

variable "prod_environment_id" {
  description = "The Power Platform environment ID of the production environment."
  type        = string
}

variable "share_with_team_id" {
  description = "The Dataverse team ID to share the pipeline with."
  type        = string
  default     = null
}

variable "staging_environment_id" {
  description = "The Power Platform environment ID of the staging environment."
  type        = string
}

variable "test_environment_id" {
  description = "The Power Platform environment ID of the test environment."
  type        = string
}
