variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "profile_name" {
  description = "Name of the Fargate profile"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace for the Fargate profile"
  type        = string
}

variable "labels" {
  description = "Kubernetes labels for pod selection"
  type        = map(string)
  default     = {}
}

variable "pod_execution_role_arn" {
  description = "ARN of the pod execution role"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for Fargate pods"
  type        = list(string)
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
