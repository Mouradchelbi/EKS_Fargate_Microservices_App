output "replication_group_id" {
  description = "ElastiCache replication group ID"
  value       = aws_elasticache_replication_group.main.id
}

output "primary_endpoint_address" {
  description = "Primary endpoint address"
  value       = aws_elasticache_replication_group.main.primary_endpoint_address
}

output "reader_endpoint_address" {
  description = "Reader endpoint address"
  value       = aws_elasticache_replication_group.main.reader_endpoint_address
}

output "configuration_endpoint_address" {
  description = "Configuration endpoint address (for cluster mode)"
  value       = aws_elasticache_replication_group.main.configuration_endpoint_address
}

output "port" {
  description = "Redis port"
  value       = 6379
}

output "security_group_id" {
  description = "Security group ID for ElastiCache"
  value       = aws_security_group.redis.id
}

output "auth_token_secret_arn" {
  description = "ARN of the Secrets Manager secret containing AUTH token"
  value       = var.transit_encryption_enabled && var.auth_token_enabled ? aws_secretsmanager_secret.redis_auth[0].arn : null
}

output "auth_token_secret_name" {
  description = "Name of the Secrets Manager secret containing AUTH token"
  value       = var.transit_encryption_enabled && var.auth_token_enabled ? aws_secretsmanager_secret.redis_auth[0].name : null
}
