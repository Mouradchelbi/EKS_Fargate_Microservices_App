data "aws_partition" "current" {}

# ElastiCache Subnet Group
resource "aws_elasticache_subnet_group" "main" {
  name       = "${var.cluster_name}-redis-subnet"
  subnet_ids = var.private_subnet_ids
  description = "ElastiCache Redis subnet group for ${var.cluster_name}"

  tags = var.tags
}

# Security Group for ElastiCache
resource "aws_security_group" "redis" {
  name_prefix = "${var.cluster_name}-redis-sg-"
  vpc_id      = var.vpc_id
  description = "Security group for ElastiCache Redis"

  ingress {
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "Redis access from VPC"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-redis-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Parameter Group
resource "aws_elasticache_parameter_group" "main" {
  name        = "${var.cluster_name}-redis-params"
  family      = var.parameter_group_family
  description = "Redis parameter group for ${var.cluster_name}"

  parameter {
    name  = "maxmemory-policy"
    value = "allkeys-lru"
  }

  parameter {
    name  = "timeout"
    value = "300"
  }

  tags = var.tags

  lifecycle {
    create_before_destroy = true
  }
}

# ElastiCache Replication Group
resource "aws_elasticache_replication_group" "main" {
  replication_group_id       = "${var.cluster_name}-redis"
  description                = "Redis cluster for ${var.cluster_name}"
  engine                     = "redis"
  engine_version             = var.engine_version
  node_type                  = var.node_type
  num_cache_clusters         = var.num_cache_nodes
  parameter_group_name       = aws_elasticache_parameter_group.main.name
  port                       = 6379
  subnet_group_name          = aws_elasticache_subnet_group.main.name
  security_group_ids         = [aws_security_group.redis.id]
  
  automatic_failover_enabled = var.num_cache_nodes > 1 ? true : false
  multi_az_enabled           = var.num_cache_nodes > 1 ? var.multi_az_enabled : false
  
  at_rest_encryption_enabled = var.at_rest_encryption_enabled
  transit_encryption_enabled = var.transit_encryption_enabled
  auth_token                 = var.transit_encryption_enabled && var.auth_token_enabled ? random_password.redis_auth[0].result : null
  
  snapshot_retention_limit   = var.snapshot_retention_limit
  snapshot_window            = var.snapshot_window
  maintenance_window         = var.maintenance_window
  
  auto_minor_version_upgrade = var.auto_minor_version_upgrade
  apply_immediately          = var.apply_immediately
  
  log_delivery_configuration {
    destination      = aws_cloudwatch_log_group.redis_slow.name
    destination_type = "cloudwatch-logs"
    log_format       = "json"
    log_type         = "slow-log"
  }

  log_delivery_configuration {
    destination      = aws_cloudwatch_log_group.redis_engine.name
    destination_type = "cloudwatch-logs"
    log_format       = "json"
    log_type         = "engine-log"
  }

  tags = var.tags
}

# Random password for Redis AUTH
resource "random_password" "redis_auth" {
  count   = var.transit_encryption_enabled && var.auth_token_enabled ? 1 : 0
  length  = 32
  special = false
}

# Secrets Manager secret for Redis AUTH token
resource "aws_secretsmanager_secret" "redis_auth" {
  count = var.transit_encryption_enabled && var.auth_token_enabled ? 1 : 0
  
  name_prefix = "${var.cluster_name}-redis-auth-"
  description = "Redis AUTH token"
  tags        = var.tags

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_secretsmanager_secret_version" "redis_auth" {
  count = var.transit_encryption_enabled && var.auth_token_enabled ? 1 : 0
  
  secret_id = aws_secretsmanager_secret.redis_auth[0].id
  secret_string = jsonencode({
    auth_token = random_password.redis_auth[0].result
    port       = 6379
  })
}

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "redis_slow" {
  name              = "/aws/elasticache/${var.cluster_name}/slow-log"
  retention_in_days = var.log_retention_days
  tags              = var.tags
}

resource "aws_cloudwatch_log_group" "redis_engine" {
  name              = "/aws/elasticache/${var.cluster_name}/engine-log"
  retention_in_days = var.log_retention_days
  tags              = var.tags
}
