# This file defines all output values exposed by the module.
# These outputs provide useful resource attributes back to the caller.
# They help other modules or root configurations easily consume and reference the resources created here.

output "state_bucket_name" {
  value = aws_s3_bucket.state.id
}

output "logging_bucket_name" {
  value = aws_s3_bucket.logging.id
}

output "state_bucket_arn" {
  value = aws_s3_bucket.state.arn
}

output "logging_bucket_arn" {
  value = aws_s3_bucket.logging.arn
}