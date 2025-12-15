terraform {
  required_version = ">= 1.5"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = local.common_tags
  }
}

locals {
  common_tags = {
    Environment = "staging"
    Project     = var.project_name
    ManagedBy   = "Terraform"
  }
}

#=============================================================================
# VPC Module
#=============================================================================
module "vpc" {
  source       = "../../modules/vpc"
  cluster_name = "${var.project_name}-staging"
  vpc_cidr     = var.vpc_cidr
  az_count     = var.az_count
  tags         = local.common_tags
}

#=============================================================================
# EKS Cluster Module
#=============================================================================
module "eks" {
  source                    = "../../modules/eks-fargate"
  cluster_name              = "${var.project_name}-staging"
  cluster_version           = var.cluster_version
  vpc_id                    = module.vpc.vpc_id
  public_subnet_ids         = module.vpc.public_subnet_ids
  private_subnet_ids        = module.vpc.private_subnet_ids
  endpoint_private_access   = true
  endpoint_public_access    = true
  enabled_cluster_log_types = ["api", "audit", "authenticator"]
  tags                      = local.common_tags
  
  depends_on = [module.vpc]
}

#=============================================================================
# RDS Aurora PostgreSQL Module
#=============================================================================
module "rds" {
  source                      = "../../modules/rds"
  cluster_name                = "${var.project_name}-staging"
  vpc_id                      = module.vpc.vpc_id
  vpc_cidr                    = var.vpc_cidr
  private_subnet_ids          = module.vpc.private_subnet_ids
  engine_version              = var.rds_engine_version
  instance_count              = var.rds_instance_count
  min_capacity                = var.rds_min_capacity
  max_capacity                = var.rds_max_capacity
  backup_retention_period     = 5
  deletion_protection         = false
  skip_final_snapshot         = true
  tags                        = local.common_tags
}

#=============================================================================
# ElastiCache Redis Module
#=============================================================================
module "elasticache" {
  source                       = "../../modules/elasticache"
  cluster_name                 = "${var.project_name}-staging"
  vpc_id                       = module.vpc.vpc_id
  vpc_cidr                     = var.vpc_cidr
  private_subnet_ids           = module.vpc.private_subnet_ids
  engine_version               = var.redis_engine_version
  node_type                    = var.redis_node_type
  num_cache_nodes              = var.redis_num_nodes
  multi_az_enabled             = true
  at_rest_encryption_enabled   = true
  transit_encryption_enabled   = true
  auth_token_enabled           = true
  snapshot_retention_limit     = 3
  tags                         = local.common_tags
}

#=============================================================================
# Application Load Balancer Module
#=============================================================================
module "alb" {
  source                     = "../../modules/alb"
  cluster_name               = "${var.project_name}-staging"
  vpc_id                     = module.vpc.vpc_id
  public_subnet_ids          = module.vpc.public_subnet_ids
  private_subnet_ids         = module.vpc.private_subnet_ids
  internal                   = false
  enable_deletion_protection = false
  tags                       = local.common_tags
}

#=============================================================================
# Fargate Profiles for Each Microservice
#=============================================================================

# 1. User Service Fargate Profile
module "fargate_profile_user_service" {
  source                 = "../../modules/fargate-profile"
  cluster_name           = module.eks.cluster_name
  profile_name           = "user-service-fp"
  namespace              = "user-service"
  pod_execution_role_arn = module.eks.fargate_pod_execution_role_arn
  private_subnet_ids     = module.vpc.private_subnet_ids
  tags                   = local.common_tags
  
  depends_on = [module.eks]
}

# 2. Order Service Fargate Profile
module "fargate_profile_order_service" {
  source                 = "../../modules/fargate-profile"
  cluster_name           = module.eks.cluster_name
  profile_name           = "order-service-fp"
  namespace              = "order-service"
  pod_execution_role_arn = module.eks.fargate_pod_execution_role_arn
  private_subnet_ids     = module.vpc.private_subnet_ids
  tags                   = local.common_tags
  
  depends_on = [module.eks]
}

# 3. Payment Service Fargate Profile
module "fargate_profile_payment_service" {
  source                 = "../../modules/fargate-profile"
  cluster_name           = module.eks.cluster_name
  profile_name           = "payment-service-fp"
  namespace              = "payment-service"
  pod_execution_role_arn = module.eks.fargate_pod_execution_role_arn
  private_subnet_ids     = module.vpc.private_subnet_ids
  tags                   = local.common_tags
  
  depends_on = [module.eks]
}

# 4. Notification Service Fargate Profile
module "fargate_profile_notification_service" {
  source                 = "../../modules/fargate-profile"
  cluster_name           = module.eks.cluster_name
  profile_name           = "notification-service-fp"
  namespace              = "notification-service"
  pod_execution_role_arn = module.eks.fargate_pod_execution_role_arn
  private_subnet_ids     = module.vpc.private_subnet_ids
  tags                   = local.common_tags
  
  depends_on = [module.eks]
}

# 5. Analytics Service Fargate Profile
module "fargate_profile_analytics_service" {
  source                 = "../../modules/fargate-profile"
  cluster_name           = module.eks.cluster_name
  profile_name           = "analytics-service-fp"
  namespace              = "analytics-service"
  pod_execution_role_arn = module.eks.fargate_pod_execution_role_arn
  private_subnet_ids     = module.vpc.private_subnet_ids
  tags                   = local.common_tags
  
  depends_on = [module.eks]
}

#=============================================================================
# IRSA Roles for Each Microservice
#=============================================================================

# 1. User Service IRSA (S3, RDS, Secrets Manager)
module "irsa_user_service" {
  source               = "../../modules/irsa"
  cluster_name         = module.eks.cluster_name
  service_name         = "user-service"
  namespace            = "user-service"
  service_account_name = "user-service-sa"
  oidc_provider_arn    = module.eks.oidc_provider_arn
  oidc_provider_url    = module.eks.oidc_provider_url
  
  policy_statements = [
    {
      Effect = "Allow"
      Action = [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListBucket"
      ]
      Resource = ["*"]
    },
    {
      Effect = "Allow"
      Action = [
        "rds:DescribeDBInstances",
        "rds:DescribeDBClusters"
      ]
      Resource = ["*"]
    },
    {
      Effect = "Allow"
      Action = [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ]
      Resource = [module.rds.secret_arn]
    }
  ]
  
  tags = local.common_tags
  depends_on = [module.eks]
}

# 2. Order Service IRSA (SQS, SNS, DynamoDB)
module "irsa_order_service" {
  source               = "../../modules/irsa"
  cluster_name         = module.eks.cluster_name
  service_name         = "order-service"
  namespace            = "order-service"
  service_account_name = "order-service-sa"
  oidc_provider_arn    = module.eks.oidc_provider_arn
  oidc_provider_url    = module.eks.oidc_provider_url
  
  policy_statements = [
    {
      Effect = "Allow"
      Action = [
        "sqs:SendMessage",
        "sqs:ReceiveMessage",
        "sqs:DeleteMessage",
        "sqs:GetQueueAttributes"
      ]
      Resource = ["*"]
    },
    {
      Effect = "Allow"
      Action = [
        "sns:Publish",
        "sns:Subscribe"
      ]
      Resource = ["*"]
    },
    {
      Effect = "Allow"
      Action = [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:UpdateItem",
        "dynamodb:DeleteItem",
        "dynamodb:Query",
        "dynamodb:Scan"
      ]
      Resource = ["*"]
    }
  ]
  
  tags = local.common_tags
  depends_on = [module.eks]
}

# 3. Payment Service IRSA (Secrets, KMS, CloudWatch)
module "irsa_payment_service" {
  source               = "../../modules/irsa"
  cluster_name         = module.eks.cluster_name
  service_name         = "payment-service"
  namespace            = "payment-service"
  service_account_name = "payment-service-sa"
  oidc_provider_arn    = module.eks.oidc_provider_arn
  oidc_provider_url    = module.eks.oidc_provider_url
  
  policy_statements = [
    {
      Effect = "Allow"
      Action = [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ]
      Resource = ["*"]
    },
    {
      Effect = "Allow"
      Action = [
        "kms:Decrypt",
        "kms:Encrypt",
        "kms:GenerateDataKey"
      ]
      Resource = ["*"]
    },
    {
      Effect = "Allow"
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "cloudwatch:PutMetricData"
      ]
      Resource = ["*"]
    }
  ]
  
  tags = local.common_tags
  depends_on = [module.eks]
}

# 4. Notification Service IRSA (SES, SNS, SQS)
module "irsa_notification_service" {
  source               = "../../modules/irsa"
  cluster_name         = module.eks.cluster_name
  service_name         = "notification-service"
  namespace            = "notification-service"
  service_account_name = "notification-service-sa"
  oidc_provider_arn    = module.eks.oidc_provider_arn
  oidc_provider_url    = module.eks.oidc_provider_url
  
  policy_statements = [
    {
      Effect = "Allow"
      Action = [
        "ses:SendEmail",
        "ses:SendRawEmail"
      ]
      Resource = ["*"]
    },
    {
      Effect = "Allow"
      Action = [
        "sns:Publish"
      ]
      Resource = ["*"]
    },
    {
      Effect = "Allow"
      Action = [
        "sqs:SendMessage",
        "sqs:ReceiveMessage",
        "sqs:DeleteMessage"
      ]
      Resource = ["*"]
    }
  ]
  
  tags = local.common_tags
  depends_on = [module.eks]
}

# 5. Analytics Service IRSA (S3, Athena, Glue, Redshift)
module "irsa_analytics_service" {
  source               = "../../modules/irsa"
  cluster_name         = module.eks.cluster_name
  service_name         = "analytics-service"
  namespace            = "analytics-service"
  service_account_name = "analytics-service-sa"
  oidc_provider_arn    = module.eks.oidc_provider_arn
  oidc_provider_url    = module.eks.oidc_provider_url
  
  policy_statements = [
    {
      Effect = "Allow"
      Action = [
        "s3:GetObject",
        "s3:PutObject",
        "s3:ListBucket"
      ]
      Resource = ["*"]
    },
    {
      Effect = "Allow"
      Action = [
        "athena:StartQueryExecution",
        "athena:GetQueryExecution",
        "athena:GetQueryResults"
      ]
      Resource = ["*"]
    },
    {
      Effect = "Allow"
      Action = [
        "glue:GetDatabase",
        "glue:GetTable",
        "glue:GetPartitions"
      ]
      Resource = ["*"]
    },
    {
      Effect = "Allow"
      Action = [
        "redshift-data:ExecuteStatement",
        "redshift-data:DescribeStatement",
        "redshift-data:GetStatementResult"
      ]
      Resource = ["*"]
    }
  ]
  
  tags = local.common_tags
  depends_on = [module.eks]
}
