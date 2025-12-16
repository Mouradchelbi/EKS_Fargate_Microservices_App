# IAM User Module
# Creates an IAM user with optional access keys and policies

resource "aws_iam_user" "user" {
  name = var.user_name
  path = var.path
  tags = var.tags
}

# Optional: Create access keys
resource "aws_iam_access_key" "user" {
  count = var.create_access_keys ? 1 : 0
  user  = aws_iam_user.user.name
}

# Optional: Attach AWS managed policies
resource "aws_iam_user_policy_attachment" "managed_policies" {
  for_each = toset(var.managed_policy_arns)
  
  user       = aws_iam_user.user.name
  policy_arn = each.value
}

# Optional: Create and attach inline policy
resource "aws_iam_user_policy" "inline_policy" {
  count = var.inline_policy_json != null ? 1 : 0
  
  name   = "${var.user_name}-inline-policy"
  user   = aws_iam_user.user.name
  policy = var.inline_policy_json
}

# Store credentials in Secrets Manager (if access keys created)
resource "aws_secretsmanager_secret" "user_credentials" {
  count = var.create_access_keys && var.store_credentials_in_secrets ? 1 : 0
  
  name_prefix = "${var.user_name}-credentials-"
  description = "Access credentials for IAM user ${var.user_name}"
  tags        = var.tags

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_secretsmanager_secret_version" "user_credentials" {
  count = var.create_access_keys && var.store_credentials_in_secrets ? 1 : 0
  
  secret_id = aws_secretsmanager_secret.user_credentials[0].id
  secret_string = jsonencode({
    username          = aws_iam_user.user.name
    access_key_id     = aws_iam_access_key.user[0].id
    secret_access_key = aws_iam_access_key.user[0].secret
    created_at        = timestamp()
  })
}
