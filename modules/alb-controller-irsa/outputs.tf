output "role_arn" {
  description = "ARN of the AWS Load Balancer Controller IAM role"
  value       = aws_iam_role.aws_load_balancer_controller.arn
}

output "role_name" {
  description = "Name of the AWS Load Balancer Controller IAM role"
  value       = aws_iam_role.aws_load_balancer_controller.name
}

output "policy_arn" {
  description = "ARN of the AWS Load Balancer Controller IAM policy"
  value       = aws_iam_policy.aws_load_balancer_controller.arn
}
