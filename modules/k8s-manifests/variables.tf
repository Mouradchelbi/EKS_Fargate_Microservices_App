variable "output_dir" {
  description = "Directory where generated manifests will be written"
  type        = string
  default     = "../../kubernetes/manifests/generated"
}

variable "user_service_irsa_role_arn" {
  description = "IRSA role ARN for user service"
  type        = string
}

variable "order_service_irsa_role_arn" {
  description = "IRSA role ARN for order service"
  type        = string
}

variable "payment_service_irsa_role_arn" {
  description = "IRSA role ARN for payment service"
  type        = string
}

variable "notification_service_irsa_role_arn" {
  description = "IRSA role ARN for notification service"
  type        = string
}

variable "analytics_service_irsa_role_arn" {
  description = "IRSA role ARN for analytics service"
  type        = string
}

variable "user_service_ecr_url" {
  description = "ECR repository URL for user service"
  type        = string
}

variable "order_service_ecr_url" {
  description = "ECR repository URL for order service"
  type        = string
}

variable "payment_service_ecr_url" {
  description = "ECR repository URL for payment service"
  type        = string
}

variable "notification_service_ecr_url" {
  description = "ECR repository URL for notification service"
  type        = string
}

variable "analytics_service_ecr_url" {
  description = "ECR repository URL for analytics service"
  type        = string
}

variable "rds_secret_arn" {
  description = "ARN of RDS credentials secret"
  type        = string
}

variable "redis_endpoint" {
  description = "Redis cluster endpoint"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}
