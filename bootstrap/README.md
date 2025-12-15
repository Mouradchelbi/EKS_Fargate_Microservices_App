# Terraform Bootstrap

This directory contains the Terraform configuration to create the S3 buckets required for storing Terraform state files for all environments (dev, staging, prod).

## Purpose

Before you can deploy any of the environments (dev/staging/prod), you need to create the S3 buckets that will store the Terraform state files. This bootstrap configuration creates those buckets with:

- **Versioning enabled**: Keeps history of state file changes
- **Encryption enabled**: AES256 encryption at rest
- **Public access blocked**: All public access is blocked for security
- **S3-native state locking**: Uses `use_lockfile = true` (no DynamoDB required)

## Prerequisites

- AWS CLI configured with credentials
- Terraform >= 1.5 installed
- Appropriate AWS permissions to create S3 buckets

## Usage

### 1. Initialize Terraform

```bash
cd bootstrap
terraform init
```

### 2. Review the Plan

```bash
terraform plan
```

This will show you the 3 S3 buckets that will be created:
- `eks-fargate-microservices-tfstate-dev`
- `eks-fargate-microservices-tfstate-staging`
- `eks-fargate-microservices-tfstate-prod`

### 3. Create the Buckets

```bash
terraform apply
```

Type `yes` when prompted to confirm.

### 4. Verify Creation

```bash
# List the buckets
aws s3 ls | grep eks-fargate-microservices-tfstate

# Verify versioning is enabled
aws s3api get-bucket-versioning --bucket eks-fargate-microservices-tfstate-dev
aws s3api get-bucket-versioning --bucket eks-fargate-microservices-tfstate-staging
aws s3api get-bucket-versioning --bucket eks-fargate-microservices-tfstate-prod
```

### 5. Deploy Your Environments

After the S3 buckets are created, you can proceed to deploy your environments:

```bash
# For dev environment
cd ../environments/dev
terraform init
terraform plan
terraform apply

# For staging environment
cd ../environments/staging
terraform init
terraform plan
terraform apply

# For prod environment
cd ../environments/prod
terraform init
terraform plan
terraform apply
```

## Important Notes

### State Locking

All environments now use **S3-native state locking** (`use_lockfile = true`) instead of DynamoDB. This means:
- No DynamoDB tables are required
- State locking is handled directly by S3
- Concurrent operations are still prevented
- No additional cost for DynamoDB

### Bootstrap State Management

⚠️ **Important**: The bootstrap configuration itself uses **local state** (stored in `bootstrap/terraform.tfstate`). This is intentional because you need S3 buckets before you can use S3 backend.

**Best practices**:
1. Run this bootstrap once to create buckets
2. Commit the local `terraform.tfstate` to version control OR
3. Manually backup `terraform.tfstate` to a secure location
4. Never modify S3 buckets manually - always use Terraform

### Bucket Names

If you need to change the bucket names (e.g., they already exist), update the bucket names in:
- `bootstrap/main.tf` (this file)
- `environments/dev/backend.tf`
- `environments/staging/backend.tf`
- `environments/prod/backend.tf`

Make sure they match exactly!

## Troubleshooting

### Bucket Already Exists Error

```
Error: creating S3 Bucket: BucketAlreadyExists
```

**Solution**: The bucket name must be globally unique across all AWS accounts. Change the bucket names in both `bootstrap/main.tf` and the environment `backend.tf` files.

### Permission Denied

```
Error: creating S3 Bucket: AccessDenied
```

**Solution**: Ensure your AWS credentials have the following permissions:
- `s3:CreateBucket`
- `s3:PutBucketVersioning`
- `s3:PutEncryptionConfiguration`
- `s3:PutBucketPublicAccessBlock`

## Cleanup

To destroy the S3 buckets (⚠️ **WARNING: This will delete all Terraform state!**):

```bash
cd bootstrap
terraform destroy
```

**Note**: You cannot destroy S3 buckets that contain objects. You must either:
1. Empty the buckets first via AWS Console or CLI
2. Add `force_destroy = true` to each `aws_s3_bucket` resource (not recommended for production)
