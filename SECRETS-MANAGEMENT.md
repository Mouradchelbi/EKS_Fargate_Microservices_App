# Secrets Management Strategy

## Overview

This infrastructure uses **AWS Secrets Manager** for managing sensitive credentials. The implementation follows AWS best practices for secure secrets handling.

## Current Implementation

### 1. RDS Database Credentials (✅ Automated)

**Location**: `modules/rds/main.tf`

The RDS module automatically creates and manages database credentials:

```hcl
resource "aws_secretsmanager_secret" "rds_credentials" {
  name_prefix = "${var.db_cluster_identifier}-credentials-"
  description = "RDS Aurora credentials for ${var.db_cluster_identifier}"
  
  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "rds_credentials" {
  secret_id = aws_secretsmanager_secret.rds_credentials.id
  secret_string = jsonencode({
    username = aws_rds_cluster.main.master_username
    password = aws_rds_cluster.main.master_password
    engine   = "postgres"
    host     = aws_rds_cluster.main.endpoint
    port     = aws_rds_cluster.main.port
    dbname   = aws_rds_cluster.main.database_name
  })
}
```

**Secret Format**:
```json
{
  "username": "dbadmin",
  "password": "auto-generated-password",
  "engine": "postgres",
  "host": "eks-fargate-db-prod.cluster-xxxxx.us-east-1.rds.amazonaws.com",
  "port": 5432,
  "dbname": "microservices"
}
```

**Access**: All microservices have IRSA permissions to read this secret via:
```json
{
  "Effect": "Allow",
  "Action": [
    "secretsmanager:GetSecretValue",
    "secretsmanager:DescribeSecret"
  ],
  "Resource": ["arn:aws:secretsmanager:*:*:secret:*-rds-credentials-*"]
}
```

### 2. Application Secrets (⚠️ Not Yet Implemented)

Currently, **application-specific secrets** (API keys, third-party credentials, etc.) are **NOT** automatically created by Terraform.

#### Recommended Approach

**Option A: Manual Secret Creation** (Quick Start)

```bash
# Create secrets manually in AWS Console or CLI
aws secretsmanager create-secret \
  --name "eks-fargate-microservices/prod/payment-service/stripe-api-key" \
  --description "Stripe API key for payment processing" \
  --secret-string '{"api_key":"sk_live_xxxxx","webhook_secret":"whsec_xxxxx"}'

aws secretsmanager create-secret \
  --name "eks-fargate-microservices/prod/notification-service/sendgrid-api-key" \
  --description "SendGrid API key for email notifications" \
  --secret-string '{"api_key":"SG.xxxxx"}'
```

**Option B: Terraform Module** (Production Ready)

Create a new module at `modules/secrets/` to manage application secrets:

```hcl
# modules/secrets/main.tf
resource "aws_secretsmanager_secret" "app_secret" {
  name_prefix = var.secret_name_prefix
  description = var.description
  
  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "app_secret" {
  secret_id     = aws_secretsmanager_secret.app_secret.id
  secret_string = jsonencode(var.secret_data)
}
```

Then instantiate in `environments/prod/main.tf`:

```hcl
module "payment_stripe_secret" {
  source = "../../modules/secrets"
  
  secret_name_prefix = "eks-fargate-microservices/prod/payment-service/stripe-"
  description        = "Stripe API credentials"
  secret_data = {
    api_key        = var.stripe_api_key        # From tfvars or env variable
    webhook_secret = var.stripe_webhook_secret
  }
  
  tags = local.common_tags
}
```

## IRSA Permissions Summary

Each microservice already has Secrets Manager permissions configured:

### User Service IRSA Role
```json
{
  "Effect": "Allow",
  "Action": [
    "secretsmanager:GetSecretValue",
    "secretsmanager:DescribeSecret"
  ],
  "Resource": [
    "arn:aws:secretsmanager:*:*:secret:*-rds-credentials-*",
    "arn:aws:secretsmanager:*:*:secret:eks-fargate-microservices/*/user-service/*"
  ]
}
```

### Payment Service IRSA Role
```json
{
  "Effect": "Allow",
  "Action": [
    "secretsmanager:GetSecretValue",
    "secretsmanager:DescribeSecret"
  ],
  "Resource": [
    "arn:aws:secretsmanager:*:*:secret:eks-fargate-microservices/*/payment-service/*"
  ]
}
```

## Best Practices

### 1. Secret Naming Convention
```
eks-fargate-microservices/{environment}/{service-name}/{secret-type}
```

Examples:
- `eks-fargate-microservices/prod/payment-service/stripe-api-key`
- `eks-fargate-microservices/prod/notification-service/sendgrid-api-key`
- `eks-fargate-microservices/prod/analytics-service/redshift-credentials`

### 2. Secret Rotation

Enable automatic rotation for long-lived secrets:

```bash
aws secretsmanager rotate-secret \
  --secret-id eks-fargate-microservices/prod/payment-service/stripe-api-key \
  --rotation-lambda-arn arn:aws:lambda:us-east-1:123456789012:function:secret-rotation \
  --rotation-rules AutomaticallyAfterDays=90
```

### 3. Access from Kubernetes Pods

**Using AWS SDK** (Recommended):

```python
# Python example
import boto3
import json

def get_secret(secret_name):
    client = boto3.client('secretsmanager', region_name='us-east-1')
    response = client.get_secret_value(SecretId=secret_name)
    return json.loads(response['SecretString'])

# Get RDS credentials
db_creds = get_secret('eks-fargate-db-prod-rds-credentials-xxxxx')
print(f"Database host: {db_creds['host']}")

# Get Stripe API key
stripe_creds = get_secret('eks-fargate-microservices/prod/payment-service/stripe-api-key')
print(f"Stripe API key: {stripe_creds['api_key']}")
```

**Using External Secrets Operator** (Advanced):

```yaml
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: aws-secrets
  namespace: payment-service
spec:
  provider:
    aws:
      service: SecretsManager
      region: us-east-1
      auth:
        jwt:
          serviceAccountRef:
            name: payment-service-sa
---
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: stripe-credentials
  namespace: payment-service
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: aws-secrets
    kind: SecretStore
  target:
    name: stripe-api-secret
    creationPolicy: Owner
  data:
  - secretKey: api_key
    remoteRef:
      key: eks-fargate-microservices/prod/payment-service/stripe-api-key
      property: api_key
```

## Secrets Lifecycle

### 1. Initial Setup (One-Time)
```bash
# Create application secrets manually
./scripts/create-secrets.sh
```

### 2. Development Access
```bash
# View secret (requires IAM permissions)
aws secretsmanager get-secret-value \
  --secret-id eks-fargate-microservices/prod/payment-service/stripe-api-key \
  --query SecretString \
  --output text | jq .
```

### 3. Update Secret
```bash
aws secretsmanager update-secret \
  --secret-id eks-fargate-microservices/prod/payment-service/stripe-api-key \
  --secret-string '{"api_key":"sk_live_new_key","webhook_secret":"whsec_new_secret"}'
```

### 4. Delete Secret (7-30 days recovery window)
```bash
aws secretsmanager delete-secret \
  --secret-id eks-fargate-microservices/prod/payment-service/stripe-api-key \
  --recovery-window-in-days 30
```

## Cost Considerations

- **Secrets Manager**: $0.40 per secret per month
- **API Calls**: $0.05 per 10,000 API calls
- **Current Setup**: 1 secret (RDS) = $0.40/month
- **With Application Secrets**: ~5-10 secrets = $2-4/month

## Security Considerations

✅ **Implemented**:
- IRSA for pod-level IAM permissions (no shared credentials)
- VPC endpoints for private Secrets Manager access
- Encryption at rest (AWS KMS)
- Encryption in transit (TLS)
- Least-privilege IAM policies

⚠️ **Recommended**:
- Enable CloudTrail logging for secret access auditing
- Implement secret rotation policies
- Use External Secrets Operator for GitOps workflows
- Set up SNS alerts for unauthorized access attempts

## Summary

| Component | Status | Location |
|-----------|--------|----------|
| **RDS Credentials** | ✅ Automated | `modules/rds/main.tf` |
| **IRSA Permissions** | ✅ Configured | All service IRSA roles |
| **VPC Endpoints** | ✅ Configured | `modules/vpc/main.tf` |
| **Application Secrets** | ⚠️ Manual | Create via AWS CLI/Console |
| **Secrets Rotation** | ❌ Not Configured | Optional enhancement |
| **External Secrets Operator** | ❌ Not Installed | Optional enhancement |

## Next Steps

1. **For Quick Start**: Create application secrets manually via AWS CLI (see Option A above)
2. **For Production**: Implement Terraform secrets module (see Option B above)
3. **For GitOps**: Install External Secrets Operator via Helm
4. **For Compliance**: Enable CloudTrail and configure rotation policies

---

**Related Documentation**:
- [AWS Secrets Manager Best Practices](https://docs.aws.amazon.com/secretsmanager/latest/userguide/best-practices.html)
- [IRSA Documentation](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html)
- [External Secrets Operator](https://external-secrets.io/)
