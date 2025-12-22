output "bucket_name" {
  description = "Name of the S3 bucket"
  value       = aws_s3_bucket.this.id
}

output "bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = aws_s3_bucket.this.arn
}

output "bucket_region" {
  description = "Region where the S3 bucket is created"
  value       = aws_s3_bucket.this.region
}

# Endpoints

output "bucket_domain_name" {
  description = "Bucket domain name"
  value       = aws_s3_bucket.this.bucket_domain_name
}

output "bucket_regional_domain_name" {
  description = "Regional bucket domain name"
  value       = aws_s3_bucket.this.bucket_regional_domain_name
}

# Encryption & security

output "encryption_algorithm" { value = var.enable_kms ? "aws:kms" : "AES256" }
output "kms_key_arn" { value = try(var.enable_kms ? var.kms_key_arn : null, null) }

# Versioning & object lock

output "versioning_enabled" {
  value       = var.versioning_enabled
  description = "Whether versioning is enabled on the bucket"
}

output "object_lock_enabled" {
  description = "Whether object lock is enabled on the bucket"
  value       = var.object_lock_enabled
}

################################
# Website
################################
output "website_endpoint" {
  description = "Website endpoint (null if website hosting is disabled)"
  value = (
    var.website.enabled
    ? aws_s3_bucket_website_configuration.this[0].website_endpoint
    : null
  )
}

################################
# Access points
################################

output "access_point_names" {
  description = "Names of S3 access points created"
  value       = keys(aws_s3_access_point.this)
}

output "access_point_arns" {
  description = "ARNs of S3 access points created"
  value = {
    for name, ap in aws_s3_access_point.this :
    name => ap.arn
  }
}