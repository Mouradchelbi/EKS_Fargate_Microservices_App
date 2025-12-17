# Create a dedicated IAM user for EKS Fargate deployments
# This user will have all permissions needed to deploy the entire infrastructure

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
# IAM Policy: EKS Fargate Deployment Policy
#==============================================================================

resource "aws_iam_policy" "eks_fargate_deployment" {
  name        = "EKSFargateDeploymentPolicy"
  path        = "/"
  description = "Comprehensive policy for EKS Fargate infrastructure deployment"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # IAM Role Management
      {
        Sid    = "IAMRoleManagement"
        Effect = "Allow"
        Action = [
          "iam:CreateRole",
          "iam:DeleteRole",
          "iam:GetRole",
          "iam:UpdateRole",
          "iam:TagRole",
          "iam:UntagRole",
          "iam:ListRoleTags"
        ]
        Resource = [
          "arn:aws:iam::685939060042:role/eks-fargate-microservices-*",
          "arn:aws:iam::685939060042:role/prod-*",
          "arn:aws:iam::685939060042:role/dev-*",
          "arn:aws:iam::685939060042:role/staging-*"
        ]
      },
      # IAM Policy Management
      {
        Sid    = "IAMPolicyManagement"
        Effect = "Allow"
        Action = [
          "iam:CreatePolicy",
          "iam:DeletePolicy",
          "iam:GetPolicy",
          "iam:GetPolicyVersion",
          "iam:ListPolicyVersions",
          "iam:CreatePolicyVersion",
          "iam:DeletePolicyVersion",
          "iam:TagPolicy",
          "iam:UntagPolicy"
        ]
        Resource = "arn:aws:iam::685939060042:policy/*"
      },
      # IAM Role Policy Attachment
      {
        Sid    = "IAMRolePolicyAttachment"
        Effect = "Allow"
        Action = [
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
          "iam:PutRolePolicy",
          "iam:DeleteRolePolicy",
          "iam:GetRolePolicy",
          "iam:ListRolePolicies",
          "iam:ListAttachedRolePolicies"
        ]
        Resource = [
          "arn:aws:iam::685939060042:role/eks-fargate-microservices-*",
          "arn:aws:iam::685939060042:role/prod-*",
          "arn:aws:iam::685939060042:role/dev-*",
          "arn:aws:iam::685939060042:role/staging-*"
        ]
      },
      # IAM OIDC Provider
      {
        Sid    = "IAMOIDCProvider"
        Effect = "Allow"
        Action = [
          "iam:CreateOpenIDConnectProvider",
          "iam:DeleteOpenIDConnectProvider",
          "iam:GetOpenIDConnectProvider",
          "iam:TagOpenIDConnectProvider",
          "iam:UntagOpenIDConnectProvider",
          "iam:UpdateOpenIDConnectProviderThumbprint"
        ]
        Resource = "arn:aws:iam::685939060042:oidc-provider/*"
      },
      # IAM PassRole
      {
        Sid    = "PassRoleToServices"
        Effect = "Allow"
        Action = "iam:PassRole"
        Resource = [
          "arn:aws:iam::685939060042:role/eks-fargate-microservices-*",
          "arn:aws:iam::685939060042:role/prod-*",
          "arn:aws:iam::685939060042:role/dev-*",
          "arn:aws:iam::685939060042:role/staging-*"
        ]
        Condition = {
          StringEquals = {
            "iam:PassedToService" = [
              "eks.amazonaws.com",
              "eks-fargate-pods.amazonaws.com",
              "monitoring.rds.amazonaws.com"
            ]
          }
        }
      },
      # EKS Full Access
      {
        Sid      = "EKSFullAccess"
        Effect   = "Allow"
        Action   = "eks:*"
        Resource = "*"
      },
      # EC2 for VPC and Networking
      {
        Sid      = "EC2NetworkingAccess"
        Effect   = "Allow"
        Action   = [
          "ec2:*"
        ]
        Resource = "*"
      },
      # RDS Full Access
      {
        Sid      = "RDSFullAccess"
        Effect   = "Allow"
        Action   = "rds:*"
        Resource = "*"
      },
      # ElastiCache Full Access
      {
        Sid      = "ElastiCacheFullAccess"
        Effect   = "Allow"
        Action   = "elasticache:*"
        Resource = "*"
      },
      # ECR Full Access
      {
        Sid      = "ECRFullAccess"
        Effect   = "Allow"
        Action   = "ecr:*"
        Resource = "*"
      },
      # Elastic Load Balancing
      {
        Sid      = "ELBFullAccess"
        Effect   = "Allow"
        Action   = [
          "elasticloadbalancing:*"
        ]
        Resource = "*"
      },
      # Secrets Manager
      {
        Sid      = "SecretsManagerAccess"
        Effect   = "Allow"
        Action   = [
          "secretsmanager:CreateSecret",
          "secretsmanager:DeleteSecret",
          "secretsmanager:DescribeSecret",
          "secretsmanager:GetSecretValue",
          "secretsmanager:PutSecretValue",
          "secretsmanager:UpdateSecret",
          "secretsmanager:TagResource",
          "secretsmanager:UntagResource"
        ]
        Resource = "*"
      },
      # CloudWatch Logs
      {
        Sid      = "CloudWatchLogsAccess"
        Effect   = "Allow"
        Action   = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:DeleteLogGroup",
          "logs:DeleteLogStream",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
          "logs:PutLogEvents",
          "logs:PutRetentionPolicy",
          "logs:TagLogGroup",
          "logs:UntagLogGroup"
        ]
        Resource = "*"
      },
      # S3 for Terraform State
      {
        Sid      = "S3TerraformStateAccess"
        Effect   = "Allow"
        Action   = [
          "s3:ListBucket",
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:GetBucketVersioning",
          "s3:PutBucketVersioning",
          "s3:GetBucketTagging",
          "s3:PutBucketTagging",
          "s3:CreateBucket",
          "s3:DeleteBucket"
        ]
        Resource = [
          "arn:aws:s3:::eks-fargate-*",
          "arn:aws:s3:::eks-fargate-*/*"
        ]
      },
      # KMS for Encryption
      {
        Sid      = "KMSAccess"
        Effect   = "Allow"
        Action   = [
          "kms:CreateKey",
          "kms:DescribeKey",
          "kms:CreateAlias",
          "kms:DeleteAlias",
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:GenerateDataKey",
          "kms:TagResource",
          "kms:UntagResource"
        ]
        Resource = "*"
      },
      # Auto Scaling
      {
        Sid      = "AutoScalingAccess"
        Effect   = "Allow"
        Action   = [
          "autoscaling:CreateAutoScalingGroup",
          "autoscaling:UpdateAutoScalingGroup",
          "autoscaling:DeleteAutoScalingGroup",
          "autoscaling:DescribeAutoScalingGroups"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name      = "EKS Fargate Deployment Policy"
    ManagedBy = "Terraform"
    Purpose   = "Complete EKS infrastructure deployment"
  }
}

#==============================================================================
# IAM User: eks-fargate-user
#==============================================================================

resource "aws_iam_user" "eks_fargate_user" {
  name = "eks-fargate-user"
  path = "/"
  
  tags = {
    Name        = "EKS Fargate User"
    ManagedBy   = "Terraform"
    Purpose     = "EKS Fargate Infrastructure Deployment"
    CreatedDate = timestamp()
  }
}

# Create access keys for the user
resource "aws_iam_access_key" "eks_fargate_user" {
  user = aws_iam_user.eks_fargate_user.name
}

# Attach the comprehensive policy to the user
resource "aws_iam_user_policy_attachment" "eks_fargate_user_policy" {
  user       = aws_iam_user.eks_fargate_user.name
  policy_arn = aws_iam_policy.eks_fargate_deployment.arn
}

#==============================================================================
# Store Credentials in Secrets Manager
#==============================================================================

resource "aws_secretsmanager_secret" "eks_fargate_user_credentials" {
  name_prefix = "eks-fargate-user-credentials-"
  description = "Access credentials for eks-fargate-user IAM user"
  
  tags = {
    User      = aws_iam_user.eks_fargate_user.name
    ManagedBy = "Terraform"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_secretsmanager_secret_version" "eks_fargate_user_credentials" {
  secret_id = aws_secretsmanager_secret.eks_fargate_user_credentials.id
  
  secret_string = jsonencode({
    username          = aws_iam_user.eks_fargate_user.name
    access_key_id     = aws_iam_access_key.eks_fargate_user.id
    secret_access_key = aws_iam_access_key.eks_fargate_user.secret
    created_at        = timestamp()
    account_id        = "685939060042"
    region            = "us-east-1"
  })
}

#==============================================================================
# Outputs
#==============================================================================

output "user_name" {
  description = "Name of the created IAM user"
  value       = aws_iam_user.eks_fargate_user.name
}

output "user_arn" {
  description = "ARN of the created IAM user"
  value       = aws_iam_user.eks_fargate_user.arn
}

output "access_key_id" {
  description = "Access Key ID for the user"
  value       = aws_iam_access_key.eks_fargate_user.id
}

output "secret_access_key" {
  description = "Secret Access Key for the user (SENSITIVE - retrieve from Secrets Manager)"
  value       = aws_iam_access_key.eks_fargate_user.secret
  sensitive   = true
}

output "credentials_secret_arn" {
  description = "ARN of the Secrets Manager secret containing user credentials"
  value       = aws_secretsmanager_secret.eks_fargate_user_credentials.arn
}

output "policy_arn" {
  description = "ARN of the created IAM policy"
  value       = aws_iam_policy.eks_fargate_deployment.arn
}

output "configure_aws_cli" {
  description = "Commands to configure AWS CLI with the new user"
  value       = <<-EOT
    # Retrieve credentials from Secrets Manager:
    aws secretsmanager get-secret-value \
      --secret-id ${aws_secretsmanager_secret.eks_fargate_user_credentials.arn} \
      --query SecretString \
      --output text | jq
    
    # Configure AWS CLI:
    aws configure --profile eks-fargate-user
    # Paste Access Key ID: ${aws_iam_access_key.eks_fargate_user.id}
    # Paste Secret Access Key: (retrieve from Secrets Manager)
    # Region: us-east-1
    # Output format: json
    
    # Test configuration:
    aws sts get-caller-identity --profile eks-fargate-user
  EOT
}
