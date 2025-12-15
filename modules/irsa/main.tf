data "aws_partition" "current" {}

# Extract OIDC provider URL without https://
locals {
  oidc_provider = replace(var.oidc_provider_url, "https://", "")
}

# IAM Role for Service Account
resource "aws_iam_role" "irsa" {
  name_prefix = "${var.cluster_name}-${var.service_name}-irsa-"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = var.oidc_provider_arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${local.oidc_provider}:sub" = "system:serviceaccount:${var.namespace}:${var.service_account_name}"
          "${local.oidc_provider}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })

  tags = merge(var.tags, {
    ServiceAccount = var.service_account_name
    Namespace      = var.namespace
  })
}

# Attach custom policies
resource "aws_iam_role_policy" "custom" {
  count = length(var.policy_statements) > 0 ? 1 : 0
  
  name = "${var.service_name}-policy"
  role = aws_iam_role.irsa.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = var.policy_statements
  })
}

# Attach AWS managed policies
resource "aws_iam_role_policy_attachment" "managed" {
  for_each = toset(var.managed_policy_arns)
  
  role       = aws_iam_role.irsa.name
  policy_arn = each.value
}
