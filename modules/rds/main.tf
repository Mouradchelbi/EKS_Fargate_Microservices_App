data "aws_partition" "current" {}

# Random password for RDS
resource "random_password" "master" {
  length  = 16
  special = true
}

# Secrets Manager secret for RDS credentials
resource "aws_secretsmanager_secret" "rds" {
  name_prefix = "${var.cluster_name}-rds-"
  description = "RDS Aurora PostgreSQL master credentials"
  tags        = var.tags

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_secretsmanager_secret_version" "rds" {
  secret_id = aws_secretsmanager_secret.rds.id
  secret_string = jsonencode({
    username = var.master_username
    password = random_password.master.result
    engine   = "postgres"
    port     = 5432
  })
}

# DB Subnet Group
resource "aws_db_subnet_group" "main" {
  name_prefix = "${var.cluster_name}-aurora-"
  subnet_ids  = var.private_subnet_ids
  description = "Aurora DB subnet group for ${var.cluster_name}"
  tags        = var.tags

  lifecycle {
    create_before_destroy = true
  }
}

# Security Group for RDS
resource "aws_security_group" "rds" {
  name_prefix = "${var.cluster_name}-rds-sg-"
  vpc_id      = var.vpc_id
  description = "Security group for Aurora PostgreSQL"

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "PostgreSQL access from VPC"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-rds-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# RDS Cluster Parameter Group
resource "aws_rds_cluster_parameter_group" "main" {
  name_prefix = "${var.cluster_name}-aurora-pg-"
  family      = var.parameter_group_family
  description = "Aurora cluster parameter group for ${var.cluster_name}"

  parameter {
    name  = "log_statement"
    value = "all"
  }

  parameter {
    name  = "log_min_duration_statement"
    value = "1000"
  }

  tags = var.tags

  lifecycle {
    create_before_destroy = true
  }
}

# RDS DB Parameter Group
resource "aws_db_parameter_group" "main" {
  name_prefix = "${var.cluster_name}-aurora-db-"
  family      = var.parameter_group_family
  description = "Aurora DB parameter group for ${var.cluster_name}"

  tags = var.tags

  lifecycle {
    create_before_destroy = true
  }
}

# Aurora Cluster
resource "aws_rds_cluster" "main" {
  cluster_identifier     = "${var.cluster_name}-aurora"
  engine                 = "aurora-postgresql"
  engine_version         = var.engine_version
  engine_mode            = "provisioned"
  database_name          = var.database_name
  master_username        = var.master_username
  master_password        = random_password.master.result
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.main.name
  
  backup_retention_period      = var.backup_retention_period
  preferred_backup_window      = var.preferred_backup_window
  preferred_maintenance_window = var.preferred_maintenance_window
  
  enabled_cloudwatch_logs_exports = ["postgresql"]
  
  storage_encrypted = true
  kms_key_id        = var.kms_key_arn
  
  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${var.cluster_name}-aurora-final-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"
  
  deletion_protection = var.deletion_protection
  apply_immediately   = var.apply_immediately

  serverlessv2_scaling_configuration {
    max_capacity = var.max_capacity
    min_capacity = var.min_capacity
  }

  tags = var.tags

  lifecycle {
    ignore_changes = [final_snapshot_identifier]
  }
}

# Aurora Instances (Serverless v2)
resource "aws_rds_cluster_instance" "main" {
  count                = var.instance_count
  identifier           = "${var.cluster_name}-aurora-${count.index + 1}"
  cluster_identifier   = aws_rds_cluster.main.id
  instance_class       = "db.serverless"
  engine               = aws_rds_cluster.main.engine
  engine_version       = aws_rds_cluster.main.engine_version
  db_parameter_group_name = aws_db_parameter_group.main.name
  
  publicly_accessible = false
  
  performance_insights_enabled    = var.performance_insights_enabled
  performance_insights_kms_key_id = var.kms_key_arn
  
  monitoring_interval = var.monitoring_interval
  monitoring_role_arn = var.monitoring_interval > 0 ? aws_iam_role.rds_monitoring[0].arn : null

  tags = var.tags
}

# IAM Role for Enhanced Monitoring
resource "aws_iam_role" "rds_monitoring" {
  count = var.monitoring_interval > 0 ? 1 : 0
  
  name_prefix = "${var.environment}-rds-mon-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "monitoring.rds.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  count = var.monitoring_interval > 0 ? 1 : 0
  
  role       = aws_iam_role.rds_monitoring[0].name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}
