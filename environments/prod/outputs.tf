#=============================================================================
# VPC Outputs
#=============================================================================
output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnet_ids
}

#=============================================================================
# EKS Outputs
#=============================================================================
output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
}

output "eks_cluster_version" {
  description = "EKS cluster version"
  value       = module.eks.cluster_version
}

output "eks_oidc_provider_arn" {
  description = "EKS OIDC provider ARN"
  value       = module.eks.oidc_provider_arn
}

output "configure_kubectl" {
  description = "Command to configure kubectl"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

#=============================================================================
# RDS Outputs
#=============================================================================
output "rds_cluster_endpoint" {
  description = "RDS cluster writer endpoint"
  value       = module.rds.cluster_endpoint
}

output "rds_cluster_reader_endpoint" {
  description = "RDS cluster reader endpoint"
  value       = module.rds.cluster_reader_endpoint
}

output "rds_secret_arn" {
  description = "RDS credentials secret ARN"
  value       = module.rds.secret_arn
}

#=============================================================================
# ElastiCache Outputs
#=============================================================================
output "redis_primary_endpoint" {
  description = "Redis primary endpoint"
  value       = module.elasticache.primary_endpoint_address
}

output "redis_reader_endpoint" {
  description = "Redis reader endpoint"
  value       = module.elasticache.reader_endpoint_address
}

output "redis_auth_secret_arn" {
  description = "Redis AUTH token secret ARN"
  value       = module.elasticache.auth_token_secret_arn
}

#=============================================================================
# ALB Outputs
#=============================================================================
output "alb_dns_name" {
  description = "ALB DNS name"
  value       = module.alb.alb_dns_name
}

output "alb_zone_id" {
  description = "ALB hosted zone ID"
  value       = module.alb.alb_zone_id
}

#=============================================================================
# Microservices IRSA Role ARNs
#=============================================================================
output "user_service_irsa_role_arn" {
  description = "User Service IRSA role ARN"
  value       = module.irsa_user_service.role_arn
}

output "order_service_irsa_role_arn" {
  description = "Order Service IRSA role ARN"
  value       = module.irsa_order_service.role_arn
}

output "payment_service_irsa_role_arn" {
  description = "Payment Service IRSA role ARN"
  value       = module.irsa_payment_service.role_arn
}

output "notification_service_irsa_role_arn" {
  description = "Notification Service IRSA role ARN"
  value       = module.irsa_notification_service.role_arn
}

output "analytics_service_irsa_role_arn" {
  description = "Analytics Service IRSA role ARN"
  value       = module.irsa_analytics_service.role_arn
}

output "alb_controller_role_arn" {
  description = "AWS Load Balancer Controller IAM role ARN"
  value       = module.alb_controller_irsa.role_arn
}

#=============================================================================
# ECR Outputs
#=============================================================================
output "ecr_user_service_url" {
  description = "User Service ECR repository URL"
  value       = module.ecr_user_service.repository_url
}

output "ecr_order_service_url" {
  description = "Order Service ECR repository URL"
  value       = module.ecr_order_service.repository_url
}

output "ecr_payment_service_url" {
  description = "Payment Service ECR repository URL"
  value       = module.ecr_payment_service.repository_url
}

output "ecr_notification_service_url" {
  description = "Notification Service ECR repository URL"
  value       = module.ecr_notification_service.repository_url
}

output "ecr_analytics_service_url" {
  description = "Analytics Service ECR repository URL"
  value       = module.ecr_analytics_service.repository_url
}
