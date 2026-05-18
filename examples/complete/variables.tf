variable "dev_environment_id" {
  description = "The Power Platform environment ID of the development environment."
  type        = string
}

variable "host_environment_id" {
  description = "The Power Platform environment ID of the Pipelines Host environment."
  type        = string
}

variable "owner_system_user_id" {
  description = "The Dataverse system user ID that will own the pipeline records. When null, defaults to the identity running the apply."
  type        = string
  default     = null
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

variable "security_group_id" {
  description = "The Entra ID security group object ID to grant pipeline access."
  type        = string
}

variable "staging_environment_id" {
  description = "The Power Platform environment ID of the staging environment."
  type        = string
}

variable "test_environment_id" {
  description = "The Power Platform environment ID of the test environment."
  type        = string
}
