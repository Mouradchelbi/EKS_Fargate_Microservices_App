output "user_name" {
  description = "Name of the created IAM user"
  value       = aws_iam_user.user.name
}

output "user_arn" {
  description = "ARN of the created IAM user"
  value       = aws_iam_user.user.arn
}

output "access_key_id" {
  description = "Access key ID (if created)"
  value       = var.create_access_keys ? aws_iam_access_key.user[0].id : null
}

output "secret_access_key" {
  description = "Secret access key (if created) - SENSITIVE"
  value       = var.create_access_keys ? aws_iam_access_key.user[0].secret : null
  sensitive   = true
}

output "credentials_secret_arn" {
  description = "ARN of the Secrets Manager secret containing credentials"
  value       = var.create_access_keys && var.store_credentials_in_secrets ? aws_secretsmanager_secret.user_credentials[0].arn : null
}

output "user_unique_id" {
  description = "Unique ID assigned by AWS"
  value       = aws_iam_user.user.unique_id
}
