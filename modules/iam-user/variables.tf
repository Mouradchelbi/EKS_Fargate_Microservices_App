variable "user_name" {
  description = "Name of the IAM user to create"
  type        = string
}

variable "path" {
  description = "Path in which to create the user"
  type        = string
  default     = "/"
}

variable "create_access_keys" {
  description = "Whether to create access keys for this user"
  type        = bool
  default     = true
}

variable "store_credentials_in_secrets" {
  description = "Store access keys in AWS Secrets Manager (recommended)"
  type        = bool
  default     = true
}

variable "managed_policy_arns" {
  description = "List of AWS managed policy ARNs to attach to the user"
  type        = list(string)
  default     = []
}

variable "inline_policy_json" {
  description = "JSON policy document for inline policy (optional)"
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags to apply to IAM resources"
  type        = map(string)
  default     = {}
}
