provider "aws" {
  region     = "eu-west-1"
}

module "s3_bucket" {
  source      = "../../"
  bucket_name = "${var.app_name}-${var.environment}-s3"
  tags = {
    Project     = "IMS"
    app_name    = var.app_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}