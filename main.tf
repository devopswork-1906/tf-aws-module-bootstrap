# This file contains the Terraform configuration used to provision s3 bucket for terraform statefile
# as well as server access logging bucket
# --------------------------------------------------
# Logging Bucket for terraform state bucket
# --------------------------------------------------
terraform {
  required_version = ">= 1.10.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.30"
    }
  }
}

provider "aws" {
  region = var.region
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_partition" "current" {}

locals {
  logging_bucket_name = "${var.tower}-${var.environment}-terraform-${data.aws_caller_identity.current.id}-logs"
  state_bucket_name   = "${var.tower}-${var.environment}-terraform-${data.aws_caller_identity.current.id}"
}

# --------------------------------------------------
# Logging Bucket for terraform state bucket
# --------------------------------------------------
resource "aws_s3_bucket" "logging" {
  bucket = local.logging_bucket_name
  force_destroy = false
  lifecycle {
    prevent_destroy = true
  }
  tags = merge(var.tags,
    {
      Name    = local.logging_bucket_name
      Purpose = "terraform-state-bucket-access-logs"
    }
  )
}
resource "aws_s3_bucket_ownership_controls" "logging" {
  bucket = aws_s3_bucket.logging.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}
resource "aws_s3_bucket_public_access_block" "logging" {
  bucket                  = aws_s3_bucket.logging.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
resource "aws_s3_bucket_versioning" "logging" {
  bucket = aws_s3_bucket.logging.id
  versioning_configuration {
    status = "Enabled"
  }
}
resource "aws_s3_bucket_server_side_encryption_configuration" "logging" {
  bucket = aws_s3_bucket.logging.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.enable_kms ? "aws:kms" : "AES256"
      kms_master_key_id = var.enable_kms ? var.kms_key_arn : null
    }
  }
}

# --------------------------------------------------
# Terraform State Bucket 
# --------------------------------------------------
resource "aws_s3_bucket" "state" {
  bucket = local.state_bucket_name
  force_destroy = false
  lifecycle {
    prevent_destroy = true
  }
  tags = merge(var.tags,
    {
      Name    = local.state_bucket_name
      Purpose = "terraform-state-bucket"
    }
  )
}
resource "aws_s3_bucket_ownership_controls" "state" {
  bucket = aws_s3_bucket.state.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}
resource "aws_s3_bucket_public_access_block" "state" {
  bucket                  = aws_s3_bucket.state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id
  versioning_configuration {
    status = "Enabled"
  }
}
resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.enable_kms ? "aws:kms" : "AES256"
      kms_master_key_id = var.enable_kms ? var.kms_key_arn : null
    }
  }
}
# Enable Access Logging (State → Logging)
resource "aws_s3_bucket_logging" "state" {
  bucket        = aws_s3_bucket.state.id
  target_bucket = aws_s3_bucket.logging.id
  target_prefix = "terraform-state-access-logs/"
}
# LIFECYCLE RULE (abort multipart uploads)
resource "aws_s3_bucket_lifecycle_configuration" "state" {
  bucket = aws_s3_bucket.state.id
  rule {
    id     = "abort-incomplete-multipart"
    status = "Enabled"
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# --------------------------------------------------
# Bucket Policy for Terraform State Bucket
# --------------------------------------------------
data "aws_iam_policy_document" "state_bucket_policy" {
  # Allow account root to list bucket & get location
  statement {
    sid    = "AllowAccountRootList"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.id}:root"]
    }
    actions = [
      "s3:ListBucket"
    ]
    resources = [aws_s3_bucket.state.arn]
  }
  # Allow GitHub OIDC role full state object access
  statement {
    sid    = "AllowOIDCRoleStateAccess"
    effect = "Allow"

    principals {
      type = "AWS"
      identifiers = [
        "arn:aws:iam::${data.aws_caller_identity.current.id}:role/iamr-${var.tower}-${var.environment}-deploy",
        "arn:aws:iam::${data.aws_caller_identity.current.id}:role/iamr-${var.tower}-${var.environment}-read"
      ]
    }

    actions = [
      "s3:ListBucket",
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListMultipartUploadParts"
    ]

    resources = [
      aws_s3_bucket.state.arn,
      "${aws_s3_bucket.state.arn}/*"
    ]
  }
}

resource "aws_s3_bucket_policy" "state" {
  bucket = aws_s3_bucket.state.id
  policy = data.aws_iam_policy_document.state_bucket_policy.json
}