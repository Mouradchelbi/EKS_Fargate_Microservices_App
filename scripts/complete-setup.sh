#!/bin/bash

# Quick setup and deployment script for EKS Fargate Microservices
# This script orchestrates the entire deployment process

set -e

echo "🎯 EKS Fargate Microservices - Complete Setup"
echo "=============================================="
echo ""

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check prerequisites
echo "🔍 Checking prerequisites..."
echo ""

command -v terraform >/dev/null 2>&1 || { echo -e "${RED}❌ Terraform is not installed${NC}"; exit 1; }
command -v aws >/dev/null 2>&1 || { echo -e "${RED}❌ AWS CLI is not installed${NC}"; exit 1; }
command -v kubectl >/dev/null 2>&1 || { echo -e "${RED}❌ kubectl is not installed${NC}"; exit 1; }

echo -e "${GREEN}✅ All prerequisites met${NC}"
echo ""

# Get AWS account info
echo "📋 AWS Account Information:"
AWS_ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION=${AWS_REGION:-us-east-1}
echo "   Account: ${AWS_ACCOUNT}"
echo "   Region: ${AWS_REGION}"
echo ""

read -p "Continue with deployment? (yes/no): " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
    echo "Deployment cancelled"
    exit 0
fi

echo ""
echo "=================================================="
echo "PHASE 1: Create Backend Infrastructure"
echo "=================================================="
echo ""

# Check if S3 bucket exists
BUCKET_NAME="eks-fargate-microservices-tfstate-prod"
if aws s3 ls "s3://${BUCKET_NAME}" 2>&1 | grep -q 'NoSuchBucket'; then
    echo "Creating S3 bucket for Terraform state..."
    aws s3api create-bucket \
        --bucket ${BUCKET_NAME} \
        --region ${AWS_REGION}
    
    aws s3api put-bucket-versioning \
        --bucket ${BUCKET_NAME} \
        --versioning-configuration Status=Enabled
    
    echo -e "${GREEN}✅ S3 bucket created${NC}"
else
    echo -e "${YELLOW}ℹ️  S3 bucket already exists${NC}"
fi

# Check if DynamoDB table exists
TABLE_NAME="eks-fargate-microservices-tflock-prod"
if ! aws dynamodb describe-table --table-name ${TABLE_NAME} --region ${AWS_REGION} >/dev/null 2>&1; then
    echo "Creating DynamoDB table for state locking..."
    aws dynamodb create-table \
        --table-name ${TABLE_NAME} \
        --attribute-definitions AttributeName=LockID,AttributeType=S \
        --key-schema AttributeName=LockID,KeyType=HASH \
        --billing-mode PAY_PER_REQUEST \
        --region ${AWS_REGION}
    
    echo -e "${GREEN}✅ DynamoDB table created${NC}"
else
    echo -e "${YELLOW}ℹ️  DynamoDB table already exists${NC}"
fi

echo ""
echo "=================================================="
echo "PHASE 2: Deploy Infrastructure with Terraform"
echo "=================================================="
echo ""

cd environments/prod

echo "Initializing Terraform..."
terraform init

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
echo "Applying infrastructure (this will take 20-30 minutes)..."
terraform apply tfplan

echo ""
echo -e "${GREEN}✅ Infrastructure deployed successfully${NC}"

echo ""
echo "=================================================="
echo "PHASE 3: Install AWS Load Balancer Controller"
echo "=================================================="
echo ""

# Configure kubectl
CLUSTER_NAME=$(terraform output -raw eks_cluster_name)
aws eks update-kubeconfig --region ${AWS_REGION} --name ${CLUSTER_NAME}

echo "Checking if ALB Controller policy exists..."
POLICY_ARN="arn:aws:iam::${AWS_ACCOUNT}:policy/AWSLoadBalancerControllerIAMPolicy"

if ! aws iam get-policy --policy-arn ${POLICY_ARN} >/dev/null 2>&1; then
    echo "Creating IAM policy for ALB Controller..."
    curl -o /tmp/iam-policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.7.0/docs/install/iam_policy.json
    aws iam create-policy \
        --policy-name AWSLoadBalancerControllerIAMPolicy \
        --policy-document file:///tmp/iam-policy.json
    echo -e "${GREEN}✅ IAM policy created${NC}"
else
    echo -e "${YELLOW}ℹ️  IAM policy already exists${NC}"
fi

echo ""
echo "Installing ALB Controller with Helm..."
helm repo add eks https://aws.github.io/eks-charts 2>/dev/null || true
helm repo update

# Check if already installed
if helm list -n kube-system | grep -q aws-load-balancer-controller; then
    echo -e "${YELLOW}ℹ️  ALB Controller already installed, upgrading...${NC}"
    helm upgrade aws-load-balancer-controller eks/aws-load-balancer-controller \
        -n kube-system \
        --set clusterName=${CLUSTER_NAME}
else
    echo "Installing ALB Controller..."
    helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
        -n kube-system \
        --set clusterName=${CLUSTER_NAME} \
        --set serviceAccount.create=true \
        --set serviceAccount.name=aws-load-balancer-controller
fi

echo -e "${GREEN}✅ ALB Controller installed${NC}"

echo ""
echo "=================================================="
echo "PHASE 4: Deploy Microservices"
echo "=================================================="
echo ""

bash ../../scripts/deploy-microservices.sh

echo ""
echo "=================================================="
echo "🎉 DEPLOYMENT COMPLETE!"
echo "=================================================="
echo ""

# Display important outputs
echo "📊 Important Information:"
echo ""
echo "Cluster Name: ${CLUSTER_NAME}"
echo "Region: ${AWS_REGION}"
echo ""

echo "Endpoints:"
terraform output | grep -E "(endpoint|dns_name)"

echo ""
echo "kubectl Command:"
terraform output -raw configure_kubectl
echo ""

echo ""
echo -e "${GREEN}✅ All systems deployed successfully!${NC}"
echo ""
echo "Monitor your services:"
echo "  kubectl get pods -A"
echo "  kubectl logs -n <namespace> -l app=<service-name>"
echo ""
