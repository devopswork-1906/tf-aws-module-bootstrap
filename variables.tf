# This file defines all input variables used by the module.
# These variables allow users to customize and control how the AWS resources are created.
# Each variable serves as an input that lets callers adjust naming, behavior, and configuration of the module.

variable "tower" {
  description = "workload tower"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}
variable "CostCentre" {
  description = "Cost Centre tag value to apply to resources created in this account"
  type        = string
}
variable "enable_kms" {
  description = "Enable KMS encryption for S3 buckets"
  type        = bool
  default     = false
}
variable "kms_key_arn" {
  type    = string
  default = null
  validation {
    condition     = !(var.enable_kms && var.kms_key_arn == null)
    error_message = "kms_key_arn must be set when enable_kms=true"
  }
}

variable "github_tags" {
  description = "Github metadata for tagging"
  type = object({
    github_repository = string
    source_url        = string
    workflow_run_url  = string
    actor             = string
    created_at        = string
  })
}

variable "tags" {
  description = "Tags for s3 bucket"
  type        = map(string)
  default     = {}
}