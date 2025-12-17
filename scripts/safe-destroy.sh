#!/bin/bash

#==============================================================================
# Safe Destroy Script for EKS Fargate Infrastructure
#==============================================================================
# This script safely destroys infrastructure by:
# 1. Disabling deletion protection on RDS and ALB
# 2. Cleaning up ENIs (Elastic Network Interfaces)
# 3. Releasing Elastic IPs
# 4. Detaching Internet Gateway dependencies
# 5. Running terraform destroy
#==============================================================================

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get environment from argument
ENVIRONMENT=${1:-prod}

# Validate environment
if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
  echo -e "${RED}Error: Invalid environment. Use dev, staging, or prod${NC}"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_DIR="$SCRIPT_DIR/../environments/$ENVIRONMENT"

echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║         Safe Destroy - EKS Fargate Infrastructure             ║${NC}"
echo -e "${BLUE}║              Environment: ${ENVIRONMENT}                                  ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check if we're in the right directory
if [ ! -d "$ENV_DIR" ]; then
  echo -e "${RED}Error: Environment directory not found: $ENV_DIR${NC}"
  exit 1
fi

cd "$ENV_DIR"

# Initialize Terraform if needed
if [ ! -d ".terraform" ]; then
  echo -e "${YELLOW}→ Initializing Terraform...${NC}"
  terraform init
fi

#==============================================================================
# Step 1: Get resource identifiers from Terraform state
#==============================================================================
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}Step 1: Extracting resource identifiers from Terraform state${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Get VPC ID
VPC_ID=$(terraform output -raw vpc_id 2>/dev/null || echo "")
if [ -z "$VPC_ID" ]; then
  echo -e "${YELLOW}⚠ Warning: No VPC found in state. Skipping VPC-related cleanup.${NC}"
  VPC_ID=""
fi

# Get RDS Cluster ID
RDS_CLUSTER_ID=$(terraform state show module.rds.aws_rds_cluster.main 2>/dev/null | grep "cluster_identifier" | awk '{print $3}' | tr -d '"' || echo "")

# Get ALB ARN
ALB_ARN=$(terraform state show module.alb.aws_lb.main 2>/dev/null | grep "arn " | head -1 | awk '{print $3}' | tr -d '"' || echo "")

# Get EKS Cluster Name
EKS_CLUSTER_NAME=$(terraform output -raw eks_cluster_name 2>/dev/null || echo "")

echo -e "${GREEN}✓ VPC ID: ${VPC_ID:-Not found}${NC}"
echo -e "${GREEN}✓ RDS Cluster: ${RDS_CLUSTER_ID:-Not found}${NC}"
echo -e "${GREEN}✓ ALB ARN: ${ALB_ARN:-Not found}${NC}"
echo -e "${GREEN}✓ EKS Cluster: ${EKS_CLUSTER_NAME:-Not found}${NC}"
echo ""

#==============================================================================
# Step 2: Disable deletion protection on RDS
#==============================================================================
if [ -n "$RDS_CLUSTER_ID" ]; then
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${YELLOW}Step 2: Disabling RDS deletion protection${NC}"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  
  echo -e "${YELLOW}→ Checking RDS deletion protection status...${NC}"
  RDS_PROTECTION=$(aws rds describe-db-clusters \
    --db-cluster-identifier "$RDS_CLUSTER_ID" \
    --query 'DBClusters[0].DeletionProtection' \
    --output text 2>/dev/null || echo "ERROR")
  
  if [ "$RDS_PROTECTION" == "True" ]; then
    echo -e "${YELLOW}→ Disabling deletion protection on RDS cluster: $RDS_CLUSTER_ID${NC}"
    aws rds modify-db-cluster \
      --db-cluster-identifier "$RDS_CLUSTER_ID" \
      --no-deletion-protection \
      --apply-immediately >/dev/null 2>&1
    
    echo -e "${YELLOW}→ Waiting for RDS modification to apply (10 seconds)...${NC}"
    sleep 10
    echo -e "${GREEN}✓ RDS deletion protection disabled${NC}"
  else
    echo -e "${GREEN}✓ RDS deletion protection already disabled${NC}"
  fi
  echo ""
fi

#==============================================================================
# Step 3: Disable deletion protection on ALB
#==============================================================================
if [ -n "$ALB_ARN" ]; then
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${YELLOW}Step 3: Disabling ALB deletion protection${NC}"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  
  echo -e "${YELLOW}→ Checking ALB deletion protection status...${NC}"
  ALB_PROTECTION=$(aws elbv2 describe-load-balancer-attributes \
    --load-balancer-arn "$ALB_ARN" \
    --query 'Attributes[?Key==`deletion_protection.enabled`].Value' \
    --output text 2>/dev/null || echo "ERROR")
  
  if [ "$ALB_PROTECTION" == "true" ]; then
    echo -e "${YELLOW}→ Disabling deletion protection on ALB${NC}"
    aws elbv2 modify-load-balancer-attributes \
      --load-balancer-arn "$ALB_ARN" \
      --attributes Key=deletion_protection.enabled,Value=false >/dev/null 2>&1
    echo -e "${GREEN}✓ ALB deletion protection disabled${NC}"
  else
    echo -e "${GREEN}✓ ALB deletion protection already disabled${NC}"
  fi
  echo ""
fi

#==============================================================================
# Step 4: Clean up Elastic Network Interfaces (ENIs)
#==============================================================================
if [ -n "$VPC_ID" ]; then
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${YELLOW}Step 4: Cleaning up Elastic Network Interfaces${NC}"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  
  echo -e "${YELLOW}→ Finding ENIs in VPC: $VPC_ID${NC}"
  ENIS=$(aws ec2 describe-network-interfaces \
    --filters "Name=vpc-id,Values=$VPC_ID" \
    --query 'NetworkInterfaces[?Status==`available`].NetworkInterfaceId' \
    --output text 2>/dev/null || echo "")
  
  if [ -n "$ENIS" ]; then
    echo -e "${YELLOW}→ Found available ENIs to delete${NC}"
    for ENI in $ENIS; do
      echo -e "${YELLOW}  → Deleting ENI: $ENI${NC}"
      aws ec2 delete-network-interface --network-interface-id "$ENI" 2>/dev/null || echo -e "${YELLOW}    ⚠ Could not delete ENI (may be in use)${NC}"
    done
    echo -e "${GREEN}✓ ENI cleanup completed${NC}"
  else
    echo -e "${GREEN}✓ No available ENIs found to delete${NC}"
  fi
  echo ""
fi

#==============================================================================
# Step 5: Release Elastic IPs
#==============================================================================
if [ -n "$VPC_ID" ]; then
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${YELLOW}Step 5: Releasing Elastic IPs${NC}"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  
  echo -e "${YELLOW}→ Finding Elastic IPs in VPC: $VPC_ID${NC}"
  
  # Get NAT Gateway IDs in the VPC
  NAT_GATEWAYS=$(aws ec2 describe-nat-gateways \
    --filter "Name=vpc-id,Values=$VPC_ID" "Name=state,Values=available,deleting,failed" \
    --query 'NatGateways[].NatGatewayId' \
    --output text 2>/dev/null || echo "")
  
  if [ -n "$NAT_GATEWAYS" ]; then
    echo -e "${YELLOW}→ Deleting NAT Gateways...${NC}"
    for NAT_GW in $NAT_GATEWAYS; do
      echo -e "${YELLOW}  → Deleting NAT Gateway: $NAT_GW${NC}"
      aws ec2 delete-nat-gateway --nat-gateway-id "$NAT_GW" 2>/dev/null || echo -e "${YELLOW}    ⚠ NAT Gateway not found or already deleted${NC}"
    done
    
    echo -e "${YELLOW}→ Waiting for NAT Gateways to delete (30 seconds)...${NC}"
    sleep 30
  fi
  
  # Release unassociated Elastic IPs
  EIPS=$(aws ec2 describe-addresses \
    --filters "Name=domain,Values=vpc" \
    --query 'Addresses[?AssociationId==null].AllocationId' \
    --output text 2>/dev/null || echo "")
  
  if [ -n "$EIPS" ]; then
    echo -e "${YELLOW}→ Found unassociated Elastic IPs to release${NC}"
    for EIP in $EIPS; do
      echo -e "${YELLOW}  → Releasing EIP: $EIP${NC}"
      aws ec2 release-address --allocation-id "$EIP" 2>/dev/null || echo -e "${YELLOW}    ⚠ Could not release EIP (may still be associated)${NC}"
    done
    echo -e "${GREEN}✓ Elastic IP cleanup completed${NC}"
  else
    echo -e "${GREEN}✓ No unassociated Elastic IPs found${NC}"
  fi
  echo ""
fi

#==============================================================================
# Step 6: Delete EKS Node Groups (if any exist)
#==============================================================================
if [ -n "$EKS_CLUSTER_NAME" ]; then
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${YELLOW}Step 6: Checking for EKS Node Groups${NC}"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  
  NODE_GROUPS=$(aws eks list-nodegroups \
    --cluster-name "$EKS_CLUSTER_NAME" \
    --query 'nodegroups' \
    --output text 2>/dev/null || echo "")
  
  if [ -n "$NODE_GROUPS" ]; then
    echo -e "${YELLOW}→ Found node groups to delete${NC}"
    for NG in $NODE_GROUPS; do
      echo -e "${YELLOW}  → Deleting node group: $NG${NC}"
      aws eks delete-nodegroup --cluster-name "$EKS_CLUSTER_NAME" --nodegroup-name "$NG" 2>/dev/null || echo -e "${YELLOW}    ⚠ Could not delete node group${NC}"
    done
    echo -e "${YELLOW}→ Waiting for node groups to delete (60 seconds)...${NC}"
    sleep 60
  else
    echo -e "${GREEN}✓ No node groups found (Fargate-only cluster)${NC}"
  fi
  echo ""
fi

#==============================================================================
# Step 7: Final confirmation before destroy
#==============================================================================
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}Step 7: Ready to destroy infrastructure${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${RED}⚠️  WARNING: This will destroy ALL infrastructure in ${ENVIRONMENT}!${NC}"
echo -e "${RED}⚠️  This includes:${NC}"
echo -e "${RED}    - EKS Cluster and all Fargate profiles${NC}"
echo -e "${RED}    - RDS Aurora PostgreSQL database (data will be lost)${NC}"
echo -e "${RED}    - ElastiCache Redis${NC}"
echo -e "${RED}    - VPC, subnets, NAT gateways${NC}"
echo -e "${RED}    - Application Load Balancer${NC}"
echo -e "${RED}    - All ECR repositories${NC}"
echo -e "${RED}    - All IAM roles and policies${NC}"
echo ""
read -p "Type 'yes' to confirm destruction: " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
  echo -e "${YELLOW}Destroy cancelled.${NC}"
  exit 0
fi

#==============================================================================
# Step 8: Run Terraform Destroy
#==============================================================================
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}Step 8: Running Terraform destroy${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

terraform destroy -auto-approve

DESTROY_EXIT_CODE=$?

if [ $DESTROY_EXIT_CODE -eq 0 ]; then
  echo ""
  echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${GREEN}║                  ✓ Destroy Completed Successfully              ║${NC}"
  echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
  echo ""
  echo -e "${GREEN}All resources have been destroyed.${NC}"
else
  echo ""
  echo -e "${RED}╔════════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${RED}║                    ✗ Destroy Failed                            ║${NC}"
  echo -e "${RED}╚════════════════════════════════════════════════════════════════╝${NC}"
  echo ""
  echo -e "${RED}Terraform destroy encountered errors.${NC}"
  echo -e "${YELLOW}You may need to manually clean up remaining resources.${NC}"
  
  if [ -n "$VPC_ID" ]; then
    echo ""
    echo -e "${YELLOW}Manual cleanup commands:${NC}"
    echo -e "${YELLOW}1. Delete ALB manually:${NC}"
    echo -e "   aws elbv2 delete-load-balancer --load-balancer-arn $ALB_ARN"
    echo ""
    echo -e "${YELLOW}2. Delete RDS cluster manually:${NC}"
    echo -e "   aws rds delete-db-cluster --db-cluster-identifier $RDS_CLUSTER_ID --skip-final-snapshot"
    echo ""
    echo -e "${YELLOW}3. Delete VPC and dependencies:${NC}"
    echo -e "   aws ec2 delete-vpc --vpc-id $VPC_ID"
  fi
  
  exit 1
fi

exit 0
