terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.30"
    }
  }
}

############################
# Core S3 bucket
############################
resource "aws_s3_bucket" "this" {
  bucket              = var.bucket_name
  force_destroy       = var.force_destroy
  object_lock_enabled = var.object_lock_enabled

  lifecycle {
    prevent_destroy = var.prevent_destroy
  }
  tags = var.tags
}

############################
# Ownership & public access
############################
resource "aws_s3_bucket_ownership_controls" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

############################
# Public access block
############################
resource "aws_s3_bucket_public_access_block" "this" {
  count  = var.public_access_block_enabled ? 1 : 0
  bucket = aws_s3_bucket.this.id

  block_public_acls       = var.public_access_block.block_public_acls
  block_public_policy     = var.public_access_block.block_public_policy
  ignore_public_acls      = var.public_access_block.ignore_public_acls
  restrict_public_buckets = var.public_access_block.restrict_public_buckets
}

############################
# Bucket policy
############################
resource "aws_s3_bucket_policy" "this" {
  count  = var.bucket_policy != null ? 1 : 0
  bucket = aws_s3_bucket.this.id
  policy = var.bucket_policy
}

############################
# Encryption (SSE-S3 / SSE-KMS)
############################
resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.enable_kms ? "aws:kms" : "AES256"
      kms_master_key_id = var.enable_kms ? var.kms_key_arn : null
    }
  }
}

############################
# Versioning
############################
resource "aws_s3_bucket_versioning" "this" {
  count  = var.versioning_enabled ? 1 : 0
  bucket = aws_s3_bucket.this.id

  versioning_configuration {
    status = "Enabled"
  }
}

############################
# Logging
############################
resource "aws_s3_bucket_logging" "this" {
  count         = var.logging.enabled ? 1 : 0
  bucket        = aws_s3_bucket.this.id
  target_bucket = var.logging.target_bucket
  target_prefix = var.logging.target_prefix
}

############################
# Lifecycle rules
############################
resource "aws_s3_bucket_lifecycle_configuration" "this" {
  count  = length(var.lifecycle_rules) > 0 ? 1 : 0
  bucket = aws_s3_bucket.this.id

  dynamic "rule" {
    for_each = var.lifecycle_rules
    content {
      id     = rule.value.id
      status = rule.value.enabled ? "Enabled" : "Disabled"

      filter {
        prefix = rule.value.prefix
      }

      dynamic "transition" {
        for_each = rule.value.transitions
        content {
          days          = transition.value.days
          storage_class = transition.value.storage_class
        }
      }

      dynamic "noncurrent_version_expiration" {
        for_each = rule.value.noncurrent_expiration_days != null ? [1] : []
        content {
          noncurrent_days = rule.value.noncurrent_expiration_days
        }
      }

      dynamic "expiration" {
        for_each = rule.value.expiration_days != null ? [1] : []
        content {
          days = rule.value.expiration_days
        }
      }
    }
  }
}

############################
# Replication
############################
resource "aws_s3_bucket_replication_configuration" "this" {
  count  = var.replication.enabled ? 1 : 0
  bucket = aws_s3_bucket.this.id
  role   = var.replication.role_arn

  dynamic "rule" {
    for_each = var.replication.rules
    content {
      id     = rule.value.id
      status = "Enabled"

      destination {
        bucket = rule.value.destination_bucket_arn

        dynamic "encryption_configuration" {
          for_each = lookup(rule.value, "replica_kms_key_id", null) != null ? [1] : []
          content {
            replica_kms_key_id = rule.value.replica_kms_key_id
          }
        }
      }
    }
  }
}

############################
# Notifications
############################
resource "aws_s3_bucket_notification" "this" {
  count  = var.notifications.enabled ? 1 : 0
  bucket = aws_s3_bucket.this.id

  dynamic "lambda_function" {
    for_each = var.notifications.lambda
    content {
      lambda_function_arn = lambda_function.value.arn
      events              = lambda_function.value.events
      filter_prefix       = lookup(lambda_function.value, "prefix", null)
      filter_suffix       = lookup(lambda_function.value, "suffix", null)
    }
  }

  dynamic "queue" {
    for_each = var.notifications.sqs
    content {
      queue_arn = queue.value.arn
      events    = queue.value.events
    }
  }

  dynamic "topic" {
    for_each = var.notifications.sns
    content {
      topic_arn = topic.value.arn
      events    = topic.value.events
    }
  }
}

############################
# Website hosting
############################
resource "aws_s3_bucket_website_configuration" "this" {
  count  = var.website.enabled ? 1 : 0
  bucket = aws_s3_bucket.this.id

  index_document {
    suffix = var.website.index_document
  }

  error_document {
    key = var.website.error_document
  }
}

############################
# Access points
############################
resource "aws_s3_access_point" "this" {
  for_each = { for ap in var.access_points : ap.name => ap }

  name   = each.value.name
  bucket = aws_s3_bucket.this.id

  dynamic "vpc_configuration" {
    for_each = each.value.vpc_id != null ? [1] : []
    content {
      vpc_id = each.value.vpc_id
    }
  }

  policy = each.value.policy
}