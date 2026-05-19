variable "dev_environment_key" {
  description = "The key in the `environments` map that designates the developer/source environment for the pipeline."
  type        = string
  nullable    = false

  validation {
    condition     = length(var.dev_environment_key) > 0
    error_message = "dev_environment_key must not be empty."
  }
}

variable "environments" {
  description = <<DESCRIPTION
A map of Power Platform environments to register in the Pipelines Host.
Each key is a stable identifier used to reference the environment in `dev_environment_key` and `pipeline_stages[*].environment_key`.

- `id`   - The Power Platform environment ID (UUID format).
- `name` - The display name to use when registering the environment in the Pipelines Host.
DESCRIPTION
  type = map(object({
    id   = string
    name = string
  }))
  nullable = false

  validation {
    condition     = length(var.environments) >= 2
    error_message = "At least 2 environments must be provided (one dev + at least one target stage)."
  }

  validation {
    condition = alltrue([
      for k, env in var.environments :
      can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", env.id))
    ])
    error_message = "All environment IDs must be valid lowercase UUIDs (e.g., 00000000-0000-0000-0000-000000000000)."
  }

  validation {
    condition = alltrue([
      for k, env in var.environments :
      length(env.name) >= 1 && length(env.name) <= 100
    ])
    error_message = "All environment names must be between 1 and 100 characters."
  }
}

variable "host_environment_id" {
  description = "The Power Platform environment ID of the Pipelines Host environment (where the deployment pipeline Dataverse records will be created)."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", var.host_environment_id))
    error_message = "host_environment_id must be a valid lowercase UUID (e.g., 00000000-0000-0000-0000-000000000000)."
  }
}

variable "pipeline_name" {
  description = "The display name of the deployment pipeline. Must be between 1 and 100 characters."
  type        = string
  nullable    = false

  validation {
    condition     = length(var.pipeline_name) >= 1 && length(var.pipeline_name) <= 100
    error_message = "pipeline_name must be between 1 and 100 characters."
  }
}

variable "pipeline_stages" {
  description = <<DESCRIPTION
An ordered list of deployment pipeline stages. Each entry configures one target environment stage.
The list position determines the deployment order (index 0 = first stage after dev, index N = Nth target stage).
Maximum 6 stages supported.

- `environment_key`           - (Required) Key in the `environments` map for the target environment.
- `description`               - (Optional) Description for this stage.
- `deployment_spn_client_id`  - (Optional) The Azure AD client ID (application ID) of the service principal used for delegated deployments. Required when `use_delegated_deployment = true`. This maps to the `spnclientid` field on the `deploymentstage` Dataverse table.
- `is_sharing_enabled`             - (Optional) Whether sharing is enabled for this stage. Defaults to `true`.
- `require_predeployment_approval` - (Optional) Whether approval is required before deploying to this stage. Defaults to `false`.
- `require_preexport_approval`     - (Optional) Whether approval is required before the pre-export step. Only effective on the first stage. Defaults to `true`.
- `use_delegated_deployment`       - (Optional) Whether to use a delegated service principal for deployment. Defaults to `false`.
DESCRIPTION
  type = list(object({
    environment_key                = string
    description                    = optional(string)
    deployment_spn_client_id       = optional(string)
    is_sharing_enabled             = optional(bool, true)
    require_predeployment_approval = optional(bool, false)
    require_preexport_approval     = optional(bool, true)
    use_delegated_deployment       = optional(bool, false)
  }))
  nullable = false

  validation {
    condition     = length(var.pipeline_stages) >= 1
    error_message = "At least one pipeline stage must be defined."
  }

  validation {
    condition     = length(var.pipeline_stages) <= 6
    error_message = "A maximum of 6 pipeline stages are supported."
  }

  validation {
    condition = length(var.pipeline_stages) == length(toset([
      for s in var.pipeline_stages : s.environment_key
    ]))
    error_message = "Each pipeline stage must reference a unique environment_key. Duplicate environment keys are not allowed."
  }

  validation {
    condition = alltrue([
      for s in var.pipeline_stages :
      s.deployment_spn_client_id == null || can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", s.deployment_spn_client_id))
    ])
    error_message = "All deployment_spn_client_id values must be valid lowercase UUIDs (e.g., 00000000-0000-0000-0000-000000000000) or null."
  }
}

variable "security_group_id" {
  description = "The Entra ID (Azure AD) security group object ID to grant access to the deployment pipeline. The module creates a Dataverse team backed by this group, assigns the 'Deployment Pipeline User' security role, and shares the pipeline with the team."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", var.security_group_id))
    error_message = "security_group_id must be a valid lowercase UUID (e.g., 00000000-0000-0000-0000-000000000000)."
  }
}

variable "pipelines_host_url" {
  description = "The Dataverse API URL for the Pipelines Host environment (e.g., https://org.crm.dynamics.com). Used for OData REST operations."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^https://[a-zA-Z0-9][a-zA-Z0-9\\-\\.]+\\.[a-zA-Z]{2,}(/.*)?$", var.pipelines_host_url))
    error_message = "pipelines_host_url must be a valid HTTPS URL (e.g., https://org.crm.dynamics.com)."
  }
}

variable "disable_on_destroy" {
  description = "When `true`, Dataverse records (pipeline, environments, stages) are deactivated rather than deleted on `terraform destroy`. This is the safer default for production Pipelines Host environments."
  type        = bool
  default     = true
  nullable    = false
}

variable "enable_ai_deployment_notes" {
  description = "When `true`, AI-generated deployment notes are enabled for the pipeline."
  type        = bool
  default     = true
  nullable    = false
}

variable "enable_redeployment" {
  description = "When `true`, the pipeline allows redeploying the same solution version to a target environment."
  type        = bool
  default     = true
  nullable    = false
}

variable "lifecycle_state" {
  description = "The desired lifecycle state of all pipeline records. Must be `\"active\"` or `\"inactive\"`."
  type        = string
  default     = "active"
  nullable    = false

  validation {
    condition     = contains(["active", "inactive"], var.lifecycle_state)
    error_message = "lifecycle_state must be either \"active\" or \"inactive\"."
  }
}

variable "pipeline_description" {
  description = "An optional description for the deployment pipeline. Maximum 500 characters."
  type        = string
  default     = null

  validation {
    condition     = var.pipeline_description == null || length(var.pipeline_description) <= 500
    error_message = "pipeline_description must not exceed 500 characters."
  }
}

variable "validation_wait_seconds" {
  description = "The number of seconds to wait after creating deployment environment records before checking their validation status. The Pipelines Host validates environments asynchronously. Must be between 0 and 600."
  type        = number
  default     = 15
  nullable    = false

  validation {
    condition     = var.validation_wait_seconds >= 0 && var.validation_wait_seconds <= 600
    error_message = "validation_wait_seconds must be between 0 and 600."
  }
}
