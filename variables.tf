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
  default     = "eu-west-1"
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
variable "kms_key_arn" {
  description = "KMS key ARN (required if enable_kms=true)"
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags for s3 bucket"
  type        = map(string)
  default     = {}
}