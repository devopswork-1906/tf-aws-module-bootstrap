# This file defines all output values exposed by the module.
# These outputs provide useful resource attributes back to the caller.
# They help other modules or root configurations easily consume and reference the resources created here.

output "bucket_name" {
  value       = aws_s3_bucket.this.bucket
  description = "The name of the bucket created"
}

output "bucket_arn" {
  value       = aws_s3_bucket.this.arn
  description = "The ARN of the bucket"
}