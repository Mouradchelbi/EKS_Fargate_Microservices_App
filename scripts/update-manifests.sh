#!/bin/bash

################################################################################
# Update Kubernetes Manifests with Terraform Outputs
#
# This script automatically replaces placeholders in K8s manifests with actual
# values from Terraform outputs. Run after "terraform apply".
#
# Usage: ./update-manifests.sh <environment>
# Example: ./update-manifests.sh prod
################################################################################

set -e

ENVIRONMENT=${1:-prod}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFESTS_DIR="$SCRIPT_DIR/../kubernetes/manifests"
ENV_DIR="$SCRIPT_DIR/../environments/$ENVIRONMENT"

echo "🔄 Updating Kubernetes manifests for environment: $ENVIRONMENT"
echo "=================================================="

# Check if environment exists
if [ ! -d "$ENV_DIR" ]; then
    echo "❌ Error: Environment '$ENVIRONMENT' not found in environments/"
    echo "Available: dev, staging, prod"
    exit 1
fi

# Navigate to environment directory
cd "$ENV_DIR"

echo ""
echo "📊 Fetching Terraform outputs..."
echo ""

# Fetch all outputs
USER_IRSA_ARN=$(terraform output -raw user_service_irsa_role_arn 2>/dev/null || echo "")
ORDER_IRSA_ARN=$(terraform output -raw order_service_irsa_role_arn 2>/dev/null || echo "")
PAYMENT_IRSA_ARN=$(terraform output -raw payment_service_irsa_role_arn 2>/dev/null || echo "")
NOTIFICATION_IRSA_ARN=$(terraform output -raw notification_service_irsa_role_arn 2>/dev/null || echo "")
ANALYTICS_IRSA_ARN=$(terraform output -raw analytics_service_irsa_role_arn 2>/dev/null || echo "")

USER_ECR=$(terraform output -raw ecr_user_service_url 2>/dev/null || echo "nginx:latest")
ORDER_ECR=$(terraform output -raw ecr_order_service_url 2>/dev/null || echo "nginx:latest")
PAYMENT_ECR=$(terraform output -raw ecr_payment_service_url 2>/dev/null || echo "nginx:latest")
NOTIFICATION_ECR=$(terraform output -raw ecr_notification_service_url 2>/dev/null || echo "nginx:latest")
ANALYTICS_ECR=$(terraform output -raw ecr_analytics_service_url 2>/dev/null || echo "nginx:latest")

RDS_SECRET_ARN=$(terraform output -raw rds_secret_arn 2>/dev/null || echo "")
REDIS_ENDPOINT=$(terraform output -raw redis_endpoint 2>/dev/null || echo "")

CLUSTER_NAME=$(terraform output -raw cluster_name 2>/dev/null || echo "eks-fargate-microservices-$ENVIRONMENT")
AWS_REGION=$(terraform output -raw aws_region 2>/dev/null || echo "us-east-1")

# Validate required outputs
if [ -z "$USER_IRSA_ARN" ]; then
    echo "❌ Error: Cannot fetch Terraform outputs. Did you run 'terraform apply'?"
    exit 1
fi

echo "✅ Terraform outputs retrieved successfully!"
echo ""
echo "📝 Values to be inserted:"
echo "   Cluster: $CLUSTER_NAME"
echo "   Region: $AWS_REGION"
echo "   User Service IRSA: ${USER_IRSA_ARN:0:50}..."
echo "   User Service ECR: ${USER_ECR}"
echo ""

# Create a temporary directory for updated manifests
TMP_DIR=$(mktemp -d)
echo "📁 Creating updated manifests in: $TMP_DIR"
echo ""

# Function to update a manifest file
update_manifest() {
    local service=$1
    local irsa_arn=$2
    local ecr_url=$3
    local source_file="$MANIFESTS_DIR/$service.yaml"
    local dest_file="$TMP_DIR/$service.yaml"
    
    if [ ! -f "$source_file" ]; then
        echo "⚠️  Warning: $source_file not found, skipping..."
        return
    fi
    
    echo "🔧 Updating $service..."
    
    # Copy and replace placeholders
    cp "$source_file" "$dest_file"
    
    # Replace IRSA role ARN
    if [ "$service" = "user-service" ]; then
        sed -i "s|REPLACE_WITH_USER_SERVICE_IRSA_ROLE_ARN|$irsa_arn|g" "$dest_file"
    elif [ "$service" = "order-service" ]; then
        sed -i "s|REPLACE_WITH_ORDER_SERVICE_IRSA_ROLE_ARN|$irsa_arn|g" "$dest_file"
    elif [ "$service" = "payment-service" ]; then
        sed -i "s|REPLACE_WITH_PAYMENT_SERVICE_IRSA_ROLE_ARN|$irsa_arn|g" "$dest_file"
    elif [ "$service" = "notification-service" ]; then
        sed -i "s|REPLACE_WITH_NOTIFICATION_SERVICE_IRSA_ROLE_ARN|$irsa_arn|g" "$dest_file"
    elif [ "$service" = "analytics-service" ]; then
        sed -i "s|REPLACE_WITH_ANALYTICS_SERVICE_IRSA_ROLE_ARN|$irsa_arn|g" "$dest_file"
    fi
    
    # Replace ECR image URL
    sed -i "s|image: nginx:latest.*|image: $ecr_url:latest|g" "$dest_file"
    
    # Replace RDS secret ARN
    sed -i "s|REPLACE_WITH_RDS_SECRET_ARN|$RDS_SECRET_ARN|g" "$dest_file"
    
    # Replace Redis endpoint
    sed -i "s|REPLACE_WITH_REDIS_ENDPOINT|$REDIS_ENDPOINT|g" "$dest_file"
    
    # Replace AWS region
    sed -i "s|us-east-1|$AWS_REGION|g" "$dest_file"
    
    echo "   ✅ $service updated"
}

# Update all service manifests
update_manifest "user-service" "$USER_IRSA_ARN" "$USER_ECR"
update_manifest "order-service" "$ORDER_IRSA_ARN" "$ORDER_ECR"
update_manifest "payment-service" "$PAYMENT_IRSA_ARN" "$PAYMENT_ECR"
update_manifest "notification-service" "$NOTIFICATION_IRSA_ARN" "$NOTIFICATION_ECR"
update_manifest "analytics-service" "$ANALYTICS_IRSA_ARN" "$ANALYTICS_ECR"

# Copy ingress (no changes needed)
if [ -f "$MANIFESTS_DIR/ingress.yaml" ]; then
    cp "$MANIFESTS_DIR/ingress.yaml" "$TMP_DIR/ingress.yaml"
    echo "🔧 Copying ingress.yaml"
    echo "   ✅ ingress updated"
fi

echo ""
echo "✅ All manifests updated successfully!"
echo ""
echo "📂 Updated manifests location: $TMP_DIR"
echo ""
echo "🚀 Next Steps:"
echo ""
echo "1. Review the generated manifests:"
echo "   ls -la $TMP_DIR"
echo ""
echo "2. Deploy to Kubernetes:"
echo "   kubectl apply -f $TMP_DIR/"
echo ""
echo "3. Verify deployment:"
echo "   kubectl get pods --all-namespaces"
echo "   kubectl get ingress -n default"
echo ""
echo "4. Optional: Copy to manifests directory (overwrites templates):"
echo "   cp $TMP_DIR/*.yaml $MANIFESTS_DIR/"
echo ""

# Optionally apply directly
read -p "Do you want to apply these manifests to Kubernetes now? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo "🚀 Applying manifests to Kubernetes..."
    kubectl apply -f "$TMP_DIR/"
    echo ""
    echo "✅ Manifests applied successfully!"
    echo ""
    echo "📊 Check status:"
    kubectl get pods --all-namespaces
fi

echo ""
echo "🎉 Done! Manifests are ready in: $TMP_DIR"
