#!/bin/bash

################################################################################
# EKS Fargate Microservices Infrastructure - Complete Setup Script
# 
# This script is a REFERENCE ONLY - the actual infrastructure is already
# complete and deployed. Use this to understand the architecture or recreate.
#
# Author: GitHub Copilot + DevOps Team
# Date: December 2025
# Repository: https://github.com/Mouradchelbi/EKS_Fargate_Microservices_App.git
################################################################################

set -e  # Exit on error

echo "🚀 EKS Fargate Microservices Infrastructure Setup"
echo "=================================================="
echo ""
echo "⚠️  NOTE: This script is for REFERENCE purposes."
echo "    The infrastructure is already complete in this repository."
echo ""
echo "Infrastructure Components:"
echo "  ✅ 9 Terraform Modules (VPC, EKS, RDS, ElastiCache, ALB, ECR, Fargate, IRSA, ALB-Controller-IRSA)"
echo "  ✅ 3 Environments (dev, staging, prod)"
echo "  ✅ 5 Microservices with dedicated Fargate profiles"
echo "  ✅ S3 Backend with bootstrap module"
echo "  ✅ Complete documentation and deployment scripts"
echo ""
read -p "Continue to view setup details? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 0
fi

echo ""
echo "📁 Project Structure"
echo "===================="
cat << 'STRUCTURE'
eks-fargate-infrastructure/
├── bootstrap/                    # S3 backend creation (run first!)
│   ├── main.tf                  # Creates S3 buckets for all environments
│   ├── outputs.tf
│   └── variables.tf
├── modules/
│   ├── vpc/                     # Multi-AZ VPC with endpoints
│   ├── eks-fargate/             # EKS 1.31 cluster with OIDC
│   ├── rds/                     # Aurora PostgreSQL 16.4 Serverless v2
│   ├── elasticache/             # Redis 7.1 multi-AZ
│   ├── alb/                     # Application Load Balancer
│   ├── alb-controller-irsa/     # IAM role for ALB Controller
│   ├── ecr/                     # Container registries (5 repos)
│   ├── fargate-profile/         # Reusable Fargate profile module
│   └── irsa/                    # IAM Roles for Service Accounts
├── environments/
│   ├── dev/                     # Development environment
│   ├── staging/                 # Staging environment
│   └── prod/                    # Production environment
│       ├── main.tf              # Infrastructure definition
│       ├── variables.tf         # Variable declarations
│       ├── terraform.tfvars     # Variable values
│       ├── backend.tf           # S3 backend config
│       └── outputs.tf           # Outputs (ECR URLs, IRSA roles, etc.)
├── kubernetes/
│   └── manifests/               # K8s deployment manifests
│       ├── user-service.yaml
│       ├── order-service.yaml
│       ├── payment-service.yaml
│       ├── notification-service.yaml
│       ├── analytics-service.yaml
│       └── ingress.yaml
├── scripts/
│   ├── complete-setup.sh        # End-to-end deployment automation
│   └── deploy-microservices.sh  # Microservices deployment
└── Documentation/
    ├── README.md                # Main documentation
    ├── QUICKSTART.md            # Quick start guide
    ├── ARCHITECTURE.md          # Architecture details
    ├── COMPLETION.md            # Implementation status
    ├── SECRETS-MANAGEMENT.md    # Secrets management guide
    └── architecture-diagram.drawio
STRUCTURE

echo ""
echo "🔧 Technology Stack"
echo "==================="
echo "  • Terraform: 1.5+"
echo "  • AWS Provider: 5.0+"
echo "  • Kubernetes: 1.31"
echo "  • Aurora PostgreSQL: 16.4 (Serverless v2)"
echo "  • ElastiCache Redis: 7.1"
echo "  • Fargate: Latest (no EC2 nodes)"
echo "  • S3: Native state locking (use_lockfile = true)"
echo ""

echo ""
echo "🎯 5 Microservices Architecture"
echo "================================"
cat << 'SERVICES'
1. User Service
   - Namespace: user-service
   - Pods: 3 replicas (0.5 vCPU, 1GB each)
   - IRSA: S3, RDS, Secrets Manager
   - Purpose: Authentication, user management

2. Order Service
   - Namespace: order-service
   - Pods: 2 replicas (1 vCPU, 2GB each)
   - IRSA: SQS, SNS, DynamoDB
   - Purpose: Order processing, inventory

3. Payment Service
   - Namespace: payment-service
   - Pods: 2 replicas (0.5 vCPU, 1GB each)
   - IRSA: Secrets Manager, KMS, CloudWatch
   - Purpose: Payment processing, PCI compliance

4. Notification Service
   - Namespace: notification-service
   - Pods: 2 replicas (0.25 vCPU, 512MB each)
   - IRSA: SES, SNS, SQS
   - Purpose: Email, SMS, push notifications

5. Analytics Service
   - Namespace: analytics-service
   - Pods: 2 replicas (2 vCPU, 4GB each)
   - IRSA: S3, Athena, Glue, Redshift
   - Purpose: Data processing, reporting
SERVICES

echo ""
echo "🚀 Deployment Steps"
echo "==================="
cat << 'DEPLOY'

Step 1: Bootstrap S3 Backend (First Time Only)
-----------------------------------------------
cd bootstrap
terraform init
terraform apply -auto-approve
cd ..

This creates 3 S3 buckets with versioning and encryption:
  • eks-fargate-microservices-tfstate-dev
  • eks-fargate-microservices-tfstate-staging
  • eks-fargate-microservices-tfstate-prod

Step 2: Deploy Infrastructure
------------------------------
cd environments/prod  # or dev/staging
terraform init
terraform plan
terraform apply -auto-approve

Resources created (~20-30 minutes):
  ✅ VPC with 3 AZs (public + private subnets)
  ✅ NAT Gateways (3x for HA)
  ✅ VPC Endpoints (S3, ECR, Secrets Manager, etc.)
  ✅ EKS Cluster (Kubernetes 1.31)
  ✅ 5 Fargate Profiles (one per microservice)
  ✅ 6 IRSA Roles (5 services + ALB Controller)
  ✅ Aurora PostgreSQL Serverless v2
  ✅ ElastiCache Redis (multi-AZ)
  ✅ Application Load Balancer
  ✅ 5 ECR Repositories

Step 3: Configure kubectl
--------------------------
aws eks update-kubeconfig --region us-east-1 --name eks-fargate-microservices-prod

Step 4: Install AWS Load Balancer Controller
---------------------------------------------
ALB_ROLE_ARN=$(terraform output -raw alb_controller_role_arn)

helm repo add eks https://aws.github.io/eks-charts
helm repo update

helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=eks-fargate-microservices-prod \
  --set serviceAccount.create=true \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"="$ALB_ROLE_ARN"

Step 5: Build & Push Container Images
--------------------------------------
# Get ECR URLs from Terraform
USER_ECR=$(terraform output -raw ecr_user_service_url)
ORDER_ECR=$(terraform output -raw ecr_order_service_url)
PAYMENT_ECR=$(terraform output -raw ecr_payment_service_url)
NOTIFICATION_ECR=$(terraform output -raw ecr_notification_service_url)
ANALYTICS_ECR=$(terraform output -raw ecr_analytics_service_url)

# ECR login
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin ${USER_ECR%%/*}

# Build and push each service
docker build -t user-service:latest ./path/to/user-service
docker tag user-service:latest $USER_ECR:latest
docker push $USER_ECR:latest

# Repeat for all 5 services...

Step 6: Deploy Microservices to Kubernetes
-------------------------------------------
# Update manifests with Terraform outputs
USER_ROLE=$(terraform output -raw user_service_irsa_role_arn)
RDS_SECRET=$(terraform output -raw rds_secret_arn)

# Update kubernetes/manifests/*.yaml with actual values
# Then deploy:
kubectl apply -f ../../kubernetes/manifests/

# Verify
kubectl get pods --all-namespaces
kubectl get ingress -n default

Step 7: Verify Deployment
--------------------------
kubectl get nodes  # Should show Fargate nodes
kubectl get svc --all-namespaces
kubectl logs -n user-service -l app=user-service
DEPLOY

echo ""
echo "🧹 Cleanup / Destroy"
echo "===================="
cat << 'CLEANUP'

Development/Staging:
--------------------
kubectl delete -f ../../kubernetes/manifests/
cd environments/dev  # or staging
terraform destroy -auto-approve

Production (with deletion protection):
---------------------------------------
kubectl delete -f ../../kubernetes/manifests/
cd environments/prod
terraform destroy -var="deletion_protection=false" -var="skip_final_snapshot=true"

Complete Teardown (including S3 buckets):
------------------------------------------
cd bootstrap
terraform destroy -auto-approve

⚠️  ECR Note: Repositories are automatically destroyed even with images.
⚠️  RDS Note: Production creates final snapshots unless skip_final_snapshot=true.
CLEANUP

echo ""
echo "📚 Key Features & Best Practices"
echo "================================="
cat << 'FEATURES'

✅ Modular Design
  • 9 reusable Terraform modules
  • DRY principles (Fargate profiles, IRSA roles)
  • Environment-specific configurations

✅ Security
  • VPC endpoints for private AWS service access
  • IRSA for pod-level IAM permissions (no shared credentials)
  • Secrets Manager for sensitive data
  • Encryption at rest and in transit (RDS, Redis, EKS)
  • Security groups with least-privilege access

✅ High Availability
  • Multi-AZ deployment (3 availability zones)
  • Aurora Serverless v2 with auto-scaling
  • ElastiCache Redis with replication
  • NAT Gateways per AZ
  • Fargate compute (no single points of failure)

✅ Cost Optimization
  • Fargate: Pay only for resources used (~$380-550/month)
  • Aurora Serverless v2: Auto-scales based on demand
  • Lifecycle policies for ECR images
  • Dev/Staging: Smaller resource allocations

✅ State Management
  • S3 backend with versioning
  • Native S3 locking (use_lockfile = true, no DynamoDB needed)
  • Encryption at rest
  • Separate buckets per environment

✅ IAM Automation
  • All IRSA roles created by Terraform
  • Service-specific permissions (least privilege)
  • ALB Controller IRSA included
  • No manual IAM configuration required

✅ Documentation
  • README.md: Complete setup guide
  • QUICKSTART.md: Fast deployment path
  • ARCHITECTURE.md: Technical deep dive
  • COMPLETION.md: Implementation status
  • SECRETS-MANAGEMENT.md: Secrets handling guide
  • architecture-diagram.drawio: Visual architecture

✅ GitOps Ready
  • All code in Git repository
  • Environment parity (dev/staging/prod)
  • CI/CD integration ready
  • Kubernetes manifests included
FEATURES

echo ""
echo "💰 Cost Breakdown (Production)"
echo "==============================="
cat << 'COSTS'
Compute (Fargate):
  • User Service (3 pods, 0.5 vCPU, 1GB):     ~$30/month
  • Order Service (2 pods, 1 vCPU, 2GB):      ~$40/month
  • Payment Service (2 pods, 0.5 vCPU, 1GB):  ~$20/month
  • Notification Service (2 pods, 0.25 vCPU): ~$8/month
  • Analytics Service (2 pods, 2 vCPU, 4GB):  ~$80/month

Networking:
  • NAT Gateways (3 AZs):                     ~$97/month
  • ALB:                                      ~$25/month

Data Services:
  • Aurora PostgreSQL Serverless v2:          ~$50-200/month
  • ElastiCache Redis (t4g.small):            ~$30/month

Storage & Other:
  • ECR (5 repositories):                     ~$5/month
  • S3 (state files):                         ~$1/month
  • Secrets Manager:                          ~$0.40/month

Total Estimated: ~$380-550/month

Dev/Staging: ~$200-300/month (smaller resources)
COSTS

echo ""
echo "🔗 Important Links"
echo "=================="
cat << 'LINKS'
GitHub Repository:
  https://github.com/Mouradchelbi/EKS_Fargate_Microservices_App.git

AWS Documentation:
  • EKS Best Practices: https://aws.github.io/aws-eks-best-practices/
  • Fargate: https://docs.aws.amazon.com/eks/latest/userguide/fargate.html
  • IRSA: https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html
  • Aurora Serverless v2: https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/aurora-serverless-v2.html

Terraform:
  • AWS Provider: https://registry.terraform.io/providers/hashicorp/aws/latest/docs
  • S3 Backend: https://developer.hashicorp.com/terraform/language/settings/backends/s3
LINKS

echo ""
echo "🎓 Next Steps"
echo "============="
cat << 'NEXT'
1. Clone the repository:
   git clone https://github.com/Mouradchelbi/EKS_Fargate_Microservices_App.git
   cd EKS_Fargate_Microservices_App/eks-fargate-infrastructure

2. Review documentation:
   - README.md: Complete overview
   - QUICKSTART.md: Quick deployment
   - ARCHITECTURE.md: Technical details
   - SECRETS-MANAGEMENT.md: Secrets handling

3. Bootstrap the S3 backend:
   cd bootstrap
   terraform init && terraform apply -auto-approve
   cd ..

4. Deploy an environment:
   cd environments/dev  # Start with dev first!
   terraform init
   terraform plan
   terraform apply

5. Configure kubectl and deploy services:
   aws eks update-kubeconfig --region us-east-1 --name eks-fargate-microservices-dev
   kubectl get nodes

6. Build your microservices and push to ECR

7. Deploy to Kubernetes:
   kubectl apply -f ../../kubernetes/manifests/

8. Monitor and scale as needed!
NEXT

echo ""
echo "✅ Script Complete!"
echo "===================="
echo ""
echo "This infrastructure is production-ready and includes:"
echo "  • 9 Terraform modules"
echo "  • 3 environments (dev, staging, prod)"
echo "  • 5 microservices with dedicated resources"
echo "  • Complete documentation"
echo "  • Automated IRSA and Fargate profiles"
echo "  • S3 backend with native locking"
echo "  • Security best practices (VPC endpoints, encryption, IRSA)"
echo "  • High availability (multi-AZ)"
echo "  • Cost optimization"
echo ""
echo "📖 Read the documentation before deploying:"
echo "   README.md, QUICKSTART.md, ARCHITECTURE.md"
echo ""
echo "🚀 Happy deploying!"