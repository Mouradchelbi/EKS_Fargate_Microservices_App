#!/bin/bash

################################################################################
# EKS Fargate Microservices - Complete End-to-End Deployment
#
# This script automates the entire deployment process:
#   1. Bootstrap S3 backend
#   2. Deploy infrastructure with Terraform
#   3. Configure kubectl
#   4. Install AWS Load Balancer Controller
#   5. Update and deploy Kubernetes manifests
#
# Usage: ./complete-setup.sh [environment]
# Example: ./complete-setup.sh prod
################################################################################

set -e

ENVIRONMENT=${1:-prod}

echo "🎯 EKS Fargate Microservices - Complete Setup"
echo "=============================================="
echo "Environment: $ENVIRONMENT"
echo ""

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Check prerequisites
echo "🔍 Checking prerequisites..."
echo ""

command -v terraform >/dev/null 2>&1 || { echo -e "${RED}❌ Terraform is not installed${NC}"; exit 1; }
command -v aws >/dev/null 2>&1 || { echo -e "${RED}❌ AWS CLI is not installed${NC}"; exit 1; }
command -v kubectl >/dev/null 2>&1 || { echo -e "${RED}❌ kubectl is not installed${NC}"; exit 1; }
command -v helm >/dev/null 2>&1 || { echo -e "${RED}❌ Helm is not installed${NC}"; exit 1; }

echo -e "${GREEN}✅ All prerequisites met${NC}"
echo ""

# Get AWS account info
echo "📋 AWS Account Information:"
AWS_ACCOUNT=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "Unknown")
AWS_REGION=$(aws configure get region 2>/dev/null || echo "us-east-1")
echo "   Account: ${AWS_ACCOUNT}"
echo "   Region: ${AWS_REGION}"
echo ""

# Validate environment
if [ ! -d "$PROJECT_ROOT/environments/$ENVIRONMENT" ]; then
    echo -e "${RED}❌ Error: Environment '$ENVIRONMENT' not found${NC}"
    echo "Available: dev, staging, prod"
    exit 1
fi

read -p "Continue with $ENVIRONMENT deployment? (yes/no): " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
    echo "Deployment cancelled"
    exit 0
fi

echo ""
echo "=================================================="
echo "PHASE 1: Bootstrap S3 Backend"
echo "=================================================="
echo ""

cd "$PROJECT_ROOT/bootstrap"

if [ -f "terraform.tfstate" ]; then
    echo -e "${YELLOW}ℹ️  Bootstrap already applied, checking status...${NC}"
    terraform init -upgrade
    terraform plan -detailed-exitcode || {
        echo "Changes detected in bootstrap"
        read -p "Apply bootstrap changes? (yes/no): " BOOTSTRAP_APPLY
        if [ "$BOOTSTRAP_APPLY" = "yes" ]; then
            terraform apply -auto-approve
        fi
    }
else
    echo "Running bootstrap to create S3 buckets..."
    terraform init
    terraform apply -auto-approve
    echo -e "${GREEN}✅ S3 backend buckets created${NC}"
fi

echo ""
echo "=================================================="
echo "PHASE 2: Deploy Infrastructure with Terraform"
echo "=================================================="
echo ""

cd "$PROJECT_ROOT/environments/$ENVIRONMENT"

echo "Initializing Terraform..."
terraform init -upgrade

echo ""
echo "Planning infrastructure..."
terraform plan -out=tfplan

echo ""
read -p "Review the plan above. Apply changes? (yes/no): " APPLY_CONFIRM
if [ "$APPLY_CONFIRM" != "yes" ]; then
    echo "Deployment cancelled"
    exit 0
fi

echo ""
echo -e "${BLUE}⏳ Applying infrastructure (this will take 20-30 minutes)...${NC}"
terraform apply tfplan

echo ""
echo -e "${GREEN}✅ Infrastructure deployed successfully${NC}"

echo ""
echo "=================================================="
echo "PHASE 3: Configure kubectl"
echo "=================================================="
echo ""

CLUSTER_NAME=$(terraform output -raw cluster_name)
echo "Configuring kubectl for cluster: $CLUSTER_NAME"
aws eks update-kubeconfig --region ${AWS_REGION} --name ${CLUSTER_NAME}

echo -e "${GREEN}✅ kubectl configured${NC}"

echo ""
echo "Verifying cluster access..."
kubectl get nodes || echo -e "${YELLOW}⚠️  No nodes yet (Fargate nodes appear when pods are scheduled)${NC}"

echo ""
echo "=================================================="
echo "PHASE 4: Install AWS Load Balancer Controller"
echo "=================================================="
echo ""

ALB_ROLE_ARN=$(terraform output -raw alb_controller_role_arn)

echo "Adding EKS Helm repository..."
helm repo add eks https://aws.github.io/eks-charts 2>/dev/null || true
helm repo update

# Check if already installed
if helm list -n kube-system | grep -q aws-load-balancer-controller; then
    echo -e "${YELLOW}ℹ️  ALB Controller already installed, upgrading...${NC}"
    helm upgrade aws-load-balancer-controller eks/aws-load-balancer-controller \
        -n kube-system \
        --set clusterName=${CLUSTER_NAME} \
        --set serviceAccount.create=true \
        --set serviceAccount.name=aws-load-balancer-controller \
        --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"="${ALB_ROLE_ARN}"
else
    echo "Installing ALB Controller..."
    helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
        -n kube-system \
        --set clusterName=${CLUSTER_NAME} \
        --set serviceAccount.create=true \
        --set serviceAccount.name=aws-load-balancer-controller \
        --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"="${ALB_ROLE_ARN}"
fi

echo ""
echo "Waiting for ALB Controller to be ready..."
kubectl wait --for=condition=available --timeout=120s deployment/aws-load-balancer-controller -n kube-system || echo -e "${YELLOW}⚠️  Timeout waiting for ALB Controller${NC}"

echo -e "${GREEN}✅ ALB Controller installed${NC}"

echo ""
echo "=================================================="
echo "PHASE 5: Update and Deploy Kubernetes Manifests"
echo "=================================================="
echo ""

echo "Running manifest update script..."
bash "$SCRIPT_DIR/update-manifests.sh" "$ENVIRONMENT"

echo ""
echo "=================================================="
echo "🎉 DEPLOYMENT COMPLETE!"
echo "=================================================="
echo ""

# Display important outputs
echo "📊 Important Information:"
echo ""
echo -e "${BLUE}Cluster:${NC} ${CLUSTER_NAME}"
echo -e "${BLUE}Region:${NC} ${AWS_REGION}"
echo -e "${BLUE}Environment:${NC} ${ENVIRONMENT}"
echo ""

echo "🔗 Key Endpoints:"
echo "----------------------------------------"
RDS_ENDPOINT=$(terraform output -raw rds_endpoint 2>/dev/null || echo "N/A")
REDIS_ENDPOINT=$(terraform output -raw redis_endpoint 2>/dev/null || echo "N/A")
echo "RDS:   $RDS_ENDPOINT"
echo "Redis: $REDIS_ENDPOINT"
echo ""

echo "📦 ECR Repositories:"
echo "----------------------------------------"
terraform output | grep ecr | head -5

echo ""
echo "🔐 IRSA Roles:"
echo "----------------------------------------"
terraform output | grep irsa_role_arn | head -5

echo ""
echo "📝 Next Steps:"
echo "----------------------------------------"
echo "1. Build your microservices Docker images"
echo "2. Push images to ECR repositories"
echo "3. Update manifest image URLs (already done by update-manifests.sh)"
echo "4. Deploy manifests: kubectl apply -f /tmp/k8s-manifests-*/"
echo "5. Monitor: kubectl get pods --all-namespaces"
echo "6. Get ALB URL: kubectl get ingress -n default"
echo ""

echo -e "${GREEN}✅ Infrastructure deployment successful!${NC}"
echo ""
echo "📚 For more information, see:"
echo "   - README.md"
echo "   - QUICKSTART.md"
echo "   - ARCHITECTURE.md"
echo ""
