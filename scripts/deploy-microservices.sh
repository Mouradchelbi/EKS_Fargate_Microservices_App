#!/bin/bash

# Deploy script for EKS Fargate Microservices
# This script updates Kubernetes manifests with Terraform outputs and deploys them

set -e

echo "🚀 EKS Fargate Microservices Deployment Script"
echo "================================================"

# Check if we're in the right directory
if [ ! -f "main.tf" ]; then
    echo "❌ Error: Please run this script from environments/prod directory"
    exit 1
fi

# Check if Terraform outputs are available
if ! terraform output > /dev/null 2>&1; then
    echo "❌ Error: Terraform outputs not available. Run 'terraform apply' first."
    exit 1
fi

echo ""
echo "📋 Step 1: Extracting Terraform outputs..."

# Extract outputs
USER_SERVICE_ROLE=$(terraform output -raw user_service_irsa_role_arn)
ORDER_SERVICE_ROLE=$(terraform output -raw order_service_irsa_role_arn)
PAYMENT_SERVICE_ROLE=$(terraform output -raw payment_service_irsa_role_arn)
NOTIFICATION_SERVICE_ROLE=$(terraform output -raw notification_service_irsa_role_arn)
ANALYTICS_SERVICE_ROLE=$(terraform output -raw analytics_service_irsa_role_arn)
RDS_SECRET_ARN=$(terraform output -raw rds_secret_arn)
CLUSTER_NAME=$(terraform output -raw eks_cluster_name)
AWS_REGION=$(terraform output -json | jq -r '.configure_kubectl.value' | grep -oP '(?<=--region )\S+')

echo "✅ Outputs extracted successfully"

echo ""
echo "⚙️  Step 2: Configuring kubectl..."
aws eks update-kubeconfig --region ${AWS_REGION} --name ${CLUSTER_NAME}
echo "✅ kubectl configured"

echo ""
echo "📝 Step 3: Creating temporary manifests with actual values..."

MANIFEST_DIR="../../kubernetes/manifests"
TEMP_DIR="/tmp/k8s-manifests-$$"
mkdir -p ${TEMP_DIR}

# Process each manifest file
for file in ${MANIFEST_DIR}/*.yaml; do
    filename=$(basename ${file})
    echo "   Processing ${filename}..."
    
    sed -e "s|REPLACE_WITH_USER_SERVICE_IRSA_ROLE_ARN|${USER_SERVICE_ROLE}|g" \
        -e "s|REPLACE_WITH_ORDER_SERVICE_IRSA_ROLE_ARN|${ORDER_SERVICE_ROLE}|g" \
        -e "s|REPLACE_WITH_PAYMENT_SERVICE_IRSA_ROLE_ARN|${PAYMENT_SERVICE_ROLE}|g" \
        -e "s|REPLACE_WITH_NOTIFICATION_SERVICE_IRSA_ROLE_ARN|${NOTIFICATION_SERVICE_ROLE}|g" \
        -e "s|REPLACE_WITH_ANALYTICS_SERVICE_IRSA_ROLE_ARN|${ANALYTICS_SERVICE_ROLE}|g" \
        -e "s|REPLACE_WITH_RDS_SECRET_ARN|${RDS_SECRET_ARN}|g" \
        ${file} > ${TEMP_DIR}/${filename}
done

echo "✅ Manifests prepared"

echo ""
echo "🚢 Step 4: Deploying to Kubernetes..."

# Deploy manifests
kubectl apply -f ${TEMP_DIR}/

echo ""
echo "⏳ Step 5: Waiting for deployments to be ready..."
echo ""

# Wait for each namespace's deployments
for namespace in user-service order-service payment-service notification-service analytics-service; do
    echo "   Checking ${namespace}..."
    kubectl wait --for=condition=available --timeout=300s \
        deployment/${namespace} -n ${namespace} || true
done

echo ""
echo "📊 Step 6: Deployment Status"
echo "=============================="
echo ""

kubectl get pods --all-namespaces -l 'app in (user-service,order-service,payment-service,notification-service,analytics-service)'

echo ""
echo "🌐 Ingress Information:"
kubectl get ingress -n default

echo ""
echo "✅ Deployment Complete!"
echo ""
echo "Next steps:"
echo "  1. Wait for ALB to be provisioned (may take 2-3 minutes)"
echo "  2. Get ALB DNS: kubectl get ingress microservices-ingress -n default -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'"
echo "  3. Test endpoints:"
echo "     curl http://ALB_DNS/api/users/health"
echo "     curl http://ALB_DNS/api/orders/health"
echo "     curl http://ALB_DNS/api/payments/health"
echo "     curl http://ALB_DNS/api/notifications/health"
echo "     curl http://ALB_DNS/api/analytics/health"
echo ""

# Cleanup temp files
rm -rf ${TEMP_DIR}
