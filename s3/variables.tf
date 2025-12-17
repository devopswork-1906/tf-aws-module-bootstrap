variable "bucket_name" {
  description = "Name of the S3 bucket"
  type        = string
  validation {
    condition     = length(var.bucket_name) >= 3
    error_message = "bucket_name must be at least 3 characters long."
  }
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "force_destroy" {
  type    = bool
  default = false
}

variable "prevent_destroy" {
  type    = bool
  default = true
  validation {
    condition     = !(var.force_destroy && var.prevent_destroy)
    error_message = "force_destroy and prevent_destroy cannot both be true."
  }
}

############################
# Public access block
############################
variable "public_access_block_enabled" {
  type    = bool
  default = true
}

variable "public_access_block" {
  type = object({
    enabled                 = bool
    block_public_acls       = bool
    block_public_policy     = bool
    ignore_public_acls      = bool
    restrict_public_buckets = bool
  })

  default = {
    enabled                 = true
    block_public_acls       = true
    block_public_policy     = true
    ignore_public_acls      = true
    restrict_public_buckets = true
  }
}
############################
# Bucket policy
############################
variable "bucket_policy" {
  type    = string
  default = null
}

############################
# Encryption
############################
variable "enable_kms" {
  type    = bool
  default = false
}

variable "kms_key_arn" {
  type        = string
  default     = null
  description = "KMS key ARN to use when enable_kms is true"

  validation {
    condition     = !var.enable_kms || (var.kms_key_arn != null && length(var.kms_key_arn) > 0)
    error_message = "kms_key_arn must be provided when enable_kms is true."
  }
}

############################
# Versioning
############################
variable "versioning_enabled" {
  type    = bool
  default = true
}

############################
# Logging
############################
variable "logging" {
  type = object({
    enabled       = bool
    target_bucket = string
    target_prefix = string
  })

  default = {
    enabled       = false
    target_bucket = ""
    target_prefix = ""
  }
}

############################
# Lifecycle rules
############################
variable "lifecycle_rules" {
  description = "Lifecycle rules for the bucket"
  type        = list(any)
  default     = []
}

############################
# Replication
############################
variable "replication" {
  type = object({
    enabled  = bool
    role_arn = string
    rules    = list(any)
  })

  default = {
    enabled  = false
    role_arn = ""
    rules    = []
  }
}

############################
# Object lock
############################
variable "object_lock_enabled" {
  type    = bool
  default = false
}

variable "website" {
  type = object({
    enabled        = bool
    index_document = string
    error_document = string
  })

  default = {
    enabled        = false
    index_document = "index.html"
    error_document = "error.html"
  }
}

variable "access_points" {
  type    = list(any)
  default = []
}