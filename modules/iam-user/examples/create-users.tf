# Example: How to create IAM users using Terraform
# Run this from a separate directory or add to your environments/

terraform {
  required_version = ">= 1.5"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

#==============================================================================
# Example 1: Create a CI/CD user with specific policies
#==============================================================================
module "cicd_user" {
  source = "../../modules/iam-user"
  
  user_name                      = "github-actions-deploy"
  create_access_keys             = true
  store_credentials_in_secrets   = true
  
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser",
    "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  ]
  
  tags = {
    Purpose     = "CI/CD Deployment"
    ManagedBy   = "Terraform"
    Environment = "prod"
  }
}

#==============================================================================
# Example 2: Create a read-only monitoring user
#==============================================================================
module "monitoring_user" {
  source = "../../modules/iam-user"
  
  user_name                      = "monitoring-readonly"
  create_access_keys             = true
  store_credentials_in_secrets   = true
  
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/ReadOnlyAccess"
  ]
  
  tags = {
    Purpose     = "Monitoring & Observability"
    ManagedBy   = "Terraform"
    Environment = "prod"
  }
}

#==============================================================================
# Example 3: Create a developer user with custom inline policy
#==============================================================================
module "developer_user" {
  source = "../../modules/iam-user"
  
  user_name                      = "developer-jane"
  create_access_keys             = true
  store_credentials_in_secrets   = true
  
  # Custom inline policy for specific resources
  inline_policy_json = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster",
          "eks:ListClusters"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
        Resource = "*"
      }
    ]
  })
  
  tags = {
    Purpose     = "Developer Access"
    ManagedBy   = "Terraform"
    Environment = "dev"
    Team        = "Engineering"
  }
}

#==============================================================================
# Example 4: Create a user WITHOUT access keys (console access only)
#==============================================================================
module "console_user" {
  source = "../../modules/iam-user"
  
  user_name          = "admin-john"
  create_access_keys = false  # No programmatic access
  
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AdministratorAccess"
  ]
  
  tags = {
    Purpose     = "Console Administration"
    ManagedBy   = "Terraform"
    Environment = "prod"
  }
}

#==============================================================================
# Outputs
#==============================================================================

output "cicd_user_credentials_secret" {
  description = "Secrets Manager ARN containing CI/CD user credentials"
  value       = module.cicd_user.credentials_secret_arn
}

output "monitoring_user_access_key" {
  description = "Access key for monitoring user"
  value       = module.monitoring_user.access_key_id
}

output "developer_user_secret_key" {
  description = "Secret key for developer (sensitive)"
  value       = module.developer_user.secret_access_key
  sensitive   = true
}

output "all_created_users" {
  description = "Summary of all created users"
  value = {
    cicd       = module.cicd_user.user_name
    monitoring = module.monitoring_user.user_name
    developer  = module.developer_user.user_name
    console    = module.console_user.user_name
  }
}
