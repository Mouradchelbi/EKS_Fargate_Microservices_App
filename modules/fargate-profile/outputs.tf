output "fargate_profile_id" {
  description = "Fargate Profile ID"
  value       = aws_eks_fargate_profile.main.id
}

output "fargate_profile_arn" {
  description = "Fargate Profile ARN"
  value       = aws_eks_fargate_profile.main.arn
}

output "fargate_profile_status" {
  description = "Fargate Profile status"
  value       = aws_eks_fargate_profile.main.status
}
