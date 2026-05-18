variable "dev_environment_id" {
  description = "The Power Platform environment ID of the development environment."
  type        = string
}

variable "host_environment_id" {
  description = "The Power Platform environment ID of the Pipelines Host environment."
  type        = string
}

variable "pipeline_name" {
  description = "The display name of the deployment pipeline."
  type        = string
}

variable "pipelines_host_url" {
  description = "The Dataverse API URL for the Pipelines Host environment."
  type        = string
}

variable "security_group_id" {
  description = "The Entra ID security group object ID to grant pipeline access."
  type        = string
}

variable "test_environment_id" {
  description = "The Power Platform environment ID of the test environment."
  type        = string
}
