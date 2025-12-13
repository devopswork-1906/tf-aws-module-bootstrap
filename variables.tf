# This file defines all input variables used by the module.
# These variables allow users to customize and control how the AWS resources are created.
# Each variable serves as an input that lets callers adjust naming, behavior, and configuration of the module.

variable "bucket_name" {
  description = "s3 bucket name"
  type        = string
}

variable "tags" {
  description = "Tags for the bucket"
  type        = map(string)
  default     = {}
}