output "dev_bucket_name" {
  description = "Dev environment S3 bucket name"
  value       = aws_s3_bucket.tfstate_dev.id
}

output "dev_bucket_arn" {
  description = "Dev environment S3 bucket ARN"
  value       = aws_s3_bucket.tfstate_dev.arn
}

output "staging_bucket_name" {
  description = "Staging environment S3 bucket name"
  value       = aws_s3_bucket.tfstate_staging.id
}

output "staging_bucket_arn" {
  description = "Staging environment S3 bucket ARN"
  value       = aws_s3_bucket.tfstate_staging.arn
}

output "prod_bucket_name" {
  description = "Prod environment S3 bucket name"
  value       = aws_s3_bucket.tfstate_prod.id
}

output "prod_bucket_arn" {
  description = "Prod environment S3 bucket ARN"
  value       = aws_s3_bucket.tfstate_prod.arn
}
