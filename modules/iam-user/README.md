# IAM User Module

Creates IAM users with optional access keys and policies using Terraform.

## Features

- ✅ Create IAM users programmatically
- ✅ Generate access keys (optional)
- ✅ Store credentials in AWS Secrets Manager (secure)
- ✅ Attach AWS managed policies
- ✅ Create inline policies
- ✅ Proper tagging
- ✅ Sensitive output handling

## Important: Prerequisites

**Your `terraform-user` needs these additional IAM permissions to create other users:**

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "iam:CreateUser",
        "iam:DeleteUser",
        "iam:GetUser",
        "iam:UpdateUser",
        "iam:TagUser",
        "iam:UntagUser",
        "iam:CreateAccessKey",
        "iam:DeleteAccessKey",
        "iam:ListAccessKeys",
        "iam:AttachUserPolicy",
        "iam:DetachUserPolicy",
        "iam:PutUserPolicy",
        "iam:DeleteUserPolicy",
        "iam:ListUserPolicies",
        "iam:ListAttachedUserPolicies"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:CreateSecret",
        "secretsmanager:DeleteSecret",
        "secretsmanager:PutSecretValue"
      ],
      "Resource": "*"
    }
  ]
}
```

## Usage

### Example 1: Basic User with Access Keys

```hcl
module "my_user" {
  source = "./modules/iam-user"
  
  user_name                    = "new-developer"
  create_access_keys           = true
  store_credentials_in_secrets = true
  
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/ReadOnlyAccess"
  ]
  
  tags = {
    Team = "Engineering"
  }
}

# Retrieve credentials from Secrets Manager
output "credentials_location" {
  value = module.my_user.credentials_secret_arn
}
```

### Example 2: CI/CD User

```hcl
module "cicd_user" {
  source = "./modules/iam-user"
  
  user_name                    = "github-actions"
  create_access_keys           = true
  store_credentials_in_secrets = true
  
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"
  ]
}
```

### Example 3: User with Custom Inline Policy

```hcl
module "custom_user" {
  source = "./modules/iam-user"
  
  user_name          = "s3-only-user"
  create_access_keys = true
  
  inline_policy_json = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:GetObject", "s3:PutObject"]
      Resource = "arn:aws:s3:::my-bucket/*"
    }]
  })
}
```

### Example 4: Console-Only User (No Access Keys)

```hcl
module "console_user" {
  source = "./modules/iam-user"
  
  user_name          = "admin-jane"
  create_access_keys = false  # Console login only
  
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AdministratorAccess"
  ]
}
```

## How to Use This Module

### Step 1: Create the user

```bash
cd modules/iam-user/examples
terraform init
terraform apply
```

### Step 2: Retrieve credentials from Secrets Manager

```bash
# Get the secret ARN from Terraform output
SECRET_ARN=$(terraform output -raw cicd_user_credentials_secret)

# Retrieve the credentials
aws secretsmanager get-secret-value \
  --secret-id $SECRET_ARN \
  --query SecretString \
  --output text | jq
```

Output:
```json
{
  "username": "github-actions",
  "access_key_id": "AKIAIOSFODNN7EXAMPLE",
  "secret_access_key": "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
  "created_at": "2025-12-16T09:30:00Z"
}
```

### Step 3: Configure the new user

```bash
# Configure AWS CLI with new credentials
aws configure --profile new-user
# Enter the access key and secret key from Secrets Manager

# Test
aws sts get-caller-identity --profile new-user
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| user_name | Name of the IAM user | `string` | - | yes |
| path | Path in which to create user | `string` | `/` | no |
| create_access_keys | Create access keys | `bool` | `true` | no |
| store_credentials_in_secrets | Store keys in Secrets Manager | `bool` | `true` | no |
| managed_policy_arns | AWS managed policy ARNs | `list(string)` | `[]` | no |
| inline_policy_json | Inline policy JSON | `string` | `null` | no |
| tags | Resource tags | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| user_name | IAM user name |
| user_arn | IAM user ARN |
| access_key_id | Access key ID |
| secret_access_key | Secret access key (sensitive) |
| credentials_secret_arn | Secrets Manager ARN |
| user_unique_id | AWS unique ID |

## Security Best Practices

1. ✅ **Always store credentials in Secrets Manager** (enabled by default)
2. ✅ **Use least-privilege policies** - only grant necessary permissions
3. ✅ **Enable MFA** for privileged users (add manually via console)
4. ✅ **Rotate access keys regularly** (every 90 days)
5. ✅ **Use IAM roles** instead of users when possible
6. ✅ **Never commit credentials to Git**

## Common Use Cases

### Use Case 1: GitHub Actions CI/CD
Create a user for automated deployments:
```hcl
module "github_deploy" {
  source = "./modules/iam-user"
  user_name = "github-actions-prod"
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  ]
}
```

### Use Case 2: Third-Party Service Integration
Create a user for external monitoring tools:
```hcl
module "datadog" {
  source = "./modules/iam-user"
  user_name = "datadog-monitoring"
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/ReadOnlyAccess"
  ]
}
```

### Use Case 3: Developer Access
Create users for team members:
```hcl
module "dev_team" {
  for_each = toset(["alice", "bob", "charlie"])
  
  source = "./modules/iam-user"
  user_name = "dev-${each.key}"
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/PowerUserAccess"
  ]
}
```

## Troubleshooting

### Error: "User already exists"
```bash
# Remove existing user first
terraform state rm module.my_user.aws_iam_user.user
aws iam delete-user --user-name my-user
terraform apply
```

### Error: "Access denied creating user"
Your `terraform-user` needs IAM user management permissions (see Prerequisites above).

### Error: "Cannot delete user with attached policies"
```bash
# Detach policies first
aws iam list-attached-user-policies --user-name my-user
aws iam detach-user-policy --user-name my-user --policy-arn <arn>
terraform destroy
```

## Cleanup

```bash
# Remove all created users
terraform destroy -auto-approve
```

## Related Documentation

- [AWS IAM Users](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_users.html)
- [AWS Secrets Manager](https://docs.aws.amazon.com/secretsmanager/)
- [Terraform AWS IAM User](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_user)
