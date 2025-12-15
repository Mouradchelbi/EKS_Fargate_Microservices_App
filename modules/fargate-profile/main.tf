# Fargate Profile for specific namespace
resource "aws_eks_fargate_profile" "main" {
  cluster_name           = var.cluster_name
  fargate_profile_name   = var.profile_name
  pod_execution_role_arn = var.pod_execution_role_arn
  subnet_ids             = var.private_subnet_ids

  selector {
    namespace = var.namespace
    labels    = var.labels
  }

  tags = var.tags
}
