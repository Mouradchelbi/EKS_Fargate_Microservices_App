# EKS Fargate Microservices Infrastructure

Production-ready Terraform infrastructure for deploying 5 microservices on AWS EKS with Fargate compute.

## 🏗️ Architecture Overview

This infrastructure deploys a complete microservices platform with:

- **VPC**: Multi-AZ networking with public/private subnets, NAT Gateways, and VPC endpoints
- **EKS Cluster**: Kubernetes 1.31 with Fargate-only compute (no EC2 nodes)
- **Database**: Aurora PostgreSQL Serverless v2 (multi-AZ)
- **Cache**: ElastiCache Redis (multi-AZ with replication)
- **Load Balancer**: Application Load Balancer with ALB Ingress Controller
- **Security**: IAM Roles for Service Accounts (IRSA) with least-privilege access
- **5 Microservices**: Each with dedicated Fargate profile and IAM role

## 🎯 Microservices Architecture

### 1️⃣ User Service
- **Namespace**: `user-service`
- **Fargate Profile**: `user-service-fp`
- **Pods**: 3 replicas (0.5 vCPU, 1GB each)
- **IRSA Permissions**: S3, RDS, Secrets Manager
- **Purpose**: Authentication, user management

### 2️⃣ Order Service
- **Namespace**: `order-service`
- **Fargate Profile**: `order-service-fp`
- **Pods**: 2 replicas (1 vCPU, 2GB each)
- **IRSA Permissions**: SQS, SNS, DynamoDB
- **Purpose**: Order processing, inventory management

### 3️⃣ Payment Service
- **Namespace**: `payment-service`
- **Fargate Profile**: `payment-service-fp`
- **Pods**: 2 replicas (0.5 vCPU, 1GB each)
- **IRSA Permissions**: Secrets Manager, KMS, CloudWatch
- **Purpose**: Payment processing, PCI compliance

### 4️⃣ Notification Service
- **Namespace**: `notification-service`
- **Fargate Profile**: `notification-service-fp`
- **Pods**: 2 replicas (0.25 vCPU, 512MB each)
- **IRSA Permissions**: SES, SNS, SQS
- **Purpose**: Email, SMS, push notifications

### 5️⃣ Analytics Service
- **Namespace**: `analytics-service`
- **Fargate Profile**: `analytics-service-fp`
- **Pods**: 2 replicas (2 vCPU, 4GB each)
- **IRSA Permissions**: S3, Athena, Glue, Redshift
- **Purpose**: Data processing, reporting

## 📁 Project Structure

```
eks-fargate-infrastructure/
├── modules/                    # Reusable Terraform modules
│   ├── vpc/                   # VPC with endpoints
│   ├── eks-fargate/           # EKS cluster with OIDC
│   ├── rds/                   # Aurora PostgreSQL
│   ├── elasticache/           # Redis cluster
│   ├── alb/                   # Application Load Balancer
│   ├── fargate-profile/       # Fargate profile module
│   └── irsa/                  # IAM Roles for Service Accounts
├── environments/
│   ├── dev/                   # Development environment
│   ├── staging/               # Staging environment
│   └── prod/                  # Production environment
│       ├── main.tf            # Main infrastructure
│       ├── variables.tf       # Variable definitions
│       ├── terraform.tfvars   # Variable values
│       ├── backend.tf         # S3 backend config
│       └── outputs.tf         # Output values
└── kubernetes/
    └── manifests/             # K8s manifests for all services
        ├── user-service.yaml
        ├── order-service.yaml
        ├── payment-service.yaml
        ├── notification-service.yaml
        ├── analytics-service.yaml
        └── ingress.yaml
```

## 🚀 Getting Started

### Prerequisites

1. **AWS CLI** configured with appropriate credentials
2. **Terraform** >= 1.5
3. **kubectl** for Kubernetes management
4. **AWS IAM permissions** for creating EKS, VPC, RDS, etc.

### Step 1: Create S3 Backend (First Time Only)

```bash
# Use bootstrap to create S3 buckets for all environments
cd bootstrap
terraform init
terraform apply -auto-approve
cd ..
```

This creates 3 S3 buckets with:
- ✅ Versioning enabled
- ✅ Encryption at rest (AES256)
- ✅ Public access blocked
- ✅ S3-native state locking (no DynamoDB needed)

**Buckets created:**
- `eks-fargate-microservices-tfstate-dev`
- `eks-fargate-microservices-tfstate-staging`
- `eks-fargate-microservices-tfstate-prod`

### Step 2: Initialize and Deploy Infrastructure

```bash
cd environments/prod

# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Deploy infrastructure (takes ~20-30 minutes)
terraform apply -auto-approve
```

### Step 3: Configure kubectl

```bash
# Get the kubectl config command from Terraform output
aws eks update-kubeconfig --region us-east-1 --name eks-fargate-microservices-prod
```

### Step 4: Install AWS Load Balancer Controller

The IAM role for the ALB Controller is already created by Terraform! Just install the Helm chart:

```bash
# Get the IAM role ARN from Terraform outputs
ALB_ROLE_ARN=$(terraform output -raw alb_controller_role_arn)

# Add EKS Helm repository
helm repo add eks https://aws.github.io/eks-charts
helm repo update

# Install AWS Load Balancer Controller
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=eks-fargate-microservices-prod \
  --set serviceAccount.create=true \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"="$ALB_ROLE_ARN"

# Verify installation
kubectl get deployment -n kube-system aws-load-balancer-controller
```

### Step 5: Build and Push Container Images to ECR

```bash
# Get ECR repository URLs from Terraform outputs
USER_SERVICE_ECR=$(terraform output -raw ecr_user_service_url)
ORDER_SERVICE_ECR=$(terraform output -raw ecr_order_service_url)
PAYMENT_SERVICE_ECR=$(terraform output -raw ecr_payment_service_url)
NOTIFICATION_SERVICE_ECR=$(terraform output -raw ecr_notification_service_url)
ANALYTICS_SERVICE_ECR=$(terraform output -raw ecr_analytics_service_url)

# Get ECR login credentials
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin ${USER_SERVICE_ECR%%/*}

# Build and push each service (replace with your actual service directories)
# User Service
cd /path/to/user-service
docker build -t user-service:latest .
docker tag user-service:latest $USER_SERVICE_ECR:latest
docker push $USER_SERVICE_ECR:latest

# Order Service
cd /path/to/order-service
docker build -t order-service:latest .
docker tag order-service:latest $ORDER_SERVICE_ECR:latest
docker push $ORDER_SERVICE_ECR:latest

# Payment Service
cd /path/to/payment-service
docker build -t payment-service:latest .
docker tag payment-service:latest $PAYMENT_SERVICE_ECR:latest
docker push $PAYMENT_SERVICE_ECR:latest

# Notification Service
cd /path/to/notification-service
docker build -t notification-service:latest .
docker tag notification-service:latest $NOTIFICATION_SERVICE_ECR:latest
docker push $NOTIFICATION_SERVICE_ECR:latest

# Analytics Service
cd /path/to/analytics-service
docker build -t analytics-service:latest .
docker tag analytics-service:latest $ANALYTICS_SERVICE_ECR:latest
docker push $ANALYTICS_SERVICE_ECR:latest
```

### Step 6: Update Kubernetes Manifests with Terraform Outputs

```bash
# Get Terraform outputs
terraform output

# Update the manifests with actual values:
# 1. Replace ECR image URLs with your actual repository URLs from terraform outputs
# 2. Replace IRSA role ARNs with output values:
#    - REPLACE_WITH_USER_SERVICE_IRSA_ROLE_ARN
#    - REPLACE_WITH_ORDER_SERVICE_IRSA_ROLE_ARN
#    - REPLACE_WITH_PAYMENT_SERVICE_IRSA_ROLE_ARN
#    - REPLACE_WITH_NOTIFICATION_SERVICE_IRSA_ROLE_ARN
#    - REPLACE_WITH_ANALYTICS_SERVICE_IRSA_ROLE_ARN
# 3. Replace REPLACE_WITH_RDS_SECRET_ARN with actual RDS secret ARN

# Example: Update user-service.yaml with ECR URL and IRSA role
USER_ECR=$(terraform output -raw ecr_user_service_url)
USER_ROLE=$(terraform output -raw user_service_irsa_role_arn)
sed -i "s|image: .*user-service.*|image: $USER_ECR:latest|g" kubernetes/manifests/user-service.yaml
sed -i "s|REPLACE_WITH_USER_SERVICE_IRSA_ROLE_ARN|$USER_ROLE|g" kubernetes/manifests/user-service.yaml
```

### Step 7: Deploy Microservices

```bash
# Deploy all microservices
kubectl apply -f ../../kubernetes/manifests/

# Verify deployments
kubectl get pods --all-namespaces

# Check ingress
kubectl get ingress -n default
```

## 📊 Monitoring & Verification

### Check Cluster Status
```bash
kubectl get nodes
kubectl get pods -A
```

### View Service Endpoints
```bash
kubectl get svc --all-namespaces
```

### Check ALB Ingress
```bash
kubectl describe ingress microservices-ingress -n default
```

### View Logs
```bash
# User Service logs
kubectl logs -n user-service -l app=user-service

# Order Service logs
kubectl logs -n order-service -l app=order-service
```

## 🔐 Security Features

- **Network Isolation**: Private subnets for all workloads
- **Encryption**: 
  - EKS secrets encryption at rest
  - RDS encryption at rest and in transit
  - Redis encryption at rest and in transit
- **VPC Endpoints**: Private connectivity to AWS services (S3, ECR, Secrets Manager)
- **IRSA**: Pod-level IAM permissions (no shared credentials)
- **Security Groups**: Least-privilege network access
- **Secrets Management**: AWS Secrets Manager for sensitive data

## 💰 Cost Optimization

### Fargate Pricing Breakdown
- **User Service**: 3 pods × 0.5 vCPU × 1GB = ~$30/month
- **Order Service**: 2 pods × 1 vCPU × 2GB = ~$40/month
- **Payment Service**: 2 pods × 0.5 vCPU × 1GB = ~$20/month
- **Notification Service**: 2 pods × 0.25 vCPU × 512MB = ~$8/month
- **Analytics Service**: 2 pods × 2 vCPU × 4GB = ~$80/month

### Other Costs
- **NAT Gateways**: ~$97/month (3 AZs)
- **ALB**: ~$25/month
- **RDS Aurora Serverless v2**: ~$50-200/month (based on usage)
- **ElastiCache**: ~$30/month (t4g.small)

**Total Estimated Cost**: ~$380-550/month

## 🔧 Customization

### Modify Resource Allocation

Edit `environments/prod/terraform.tfvars`:

```hcl
# Scale RDS
rds_min_capacity = 2
rds_max_capacity = 8

# Scale Redis
redis_node_type = "cache.t4g.medium"
redis_num_nodes = 3
```

### Add More Microservices

1. Create new Fargate profile in `main.tf`
2. Create new IRSA role with appropriate permissions
3. Add Kubernetes manifest in `kubernetes/manifests/`

## 🧹 Cleanup

### Development/Staging Environments

```bash
# Delete Kubernetes resources first (if deployed)
kubectl delete -f ../../kubernetes/manifests/

# Destroy infrastructure (ECR repositories will be destroyed even with images)
cd environments/dev  # or environments/staging
terraform destroy -auto-approve
```

### Production Environment

Production has **deletion protection enabled** on critical resources for safety. You have two options:

#### Option 1: Disable Deletion Protection (Recommended)

```bash
# Delete Kubernetes resources first
kubectl delete -f ../../kubernetes/manifests/

# Destroy with deletion protection disabled
cd environments/prod
terraform destroy -var="deletion_protection=false" -var="skip_final_snapshot=true"
```

#### Option 2: Manual Deletion Protection Removal

```bash
# 1. Manually disable deletion protection in AWS Console:
#    - RDS: Database → Modify → Uncheck "Deletion protection"
#    - ALB: Load Balancer → Attributes → Disable "Deletion protection"

# 2. Then run destroy
terraform destroy -auto-approve
```

### Complete Teardown (Including S3 State Buckets)

```bash
# After destroying all environments, optionally remove S3 buckets
cd bootstrap
terraform destroy -auto-approve
```

⚠️ **Important Notes:**
- **ECR Repositories**: Automatically deleted even with container images (force_destroy enabled)
- **RDS Final Snapshots**: Production creates final snapshots unless `skip_final_snapshot=true`
- **Data Loss**: All data will be permanently deleted. Ensure you have backups!
- **S3 State Buckets**: Destroying these will remove all Terraform state history

## 📝 Important Notes

### RDS Final Snapshot
- Set `skip_final_snapshot = true` in variables to skip final snapshot during destroy
- Default behavior creates a final snapshot for data protection

### Domain & SSL
- Update `ingress.yaml` with your domain
- Add ACM certificate ARN to ALB module for HTTPS

### Image Registry
- Replace `nginx:latest` in manifests with your actual container images
- Consider using Amazon ECR for private image hosting

## 🛠️ Troubleshooting

### Pods Stuck in Pending
```bash
# Check Fargate profile
kubectl describe pod <pod-name> -n <namespace>

# Verify Fargate profiles exist
aws eks list-fargate-profiles --cluster-name eks-fargate-microservices-prod
```

### ALB Not Created
```bash
# Check AWS Load Balancer Controller logs
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
```

### IRSA Not Working
```bash
# Verify service account annotation
kubectl describe sa <service-account-name> -n <namespace>

# Check pod IAM role
kubectl describe pod <pod-name> -n <namespace> | grep AWS_ROLE_ARN
```

## 📚 Additional Resources

- [EKS Best Practices Guide](https://aws.github.io/aws-eks-best-practices/)
- [Fargate Documentation](https://docs.aws.amazon.com/eks/latest/userguide/fargate.html)
- [IRSA Documentation](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html)

## 🤝 Contributing

Contributions welcome! Please submit pull requests or open issues for improvements.

## 📄 License

MIT License - feel free to use this infrastructure for your projects.

---

**Built with ❤️ using Terraform and AWS EKS Fargate**
