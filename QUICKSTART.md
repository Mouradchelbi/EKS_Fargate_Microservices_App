# Quick Start Guide

## 🚀 Complete Deployment in 3 Commands

### Option 1: Automated Complete Setup

```bash
cd eks-fargate-infrastructure/scripts
./complete-setup.sh
```

This script will:
1. Create S3 backend buckets (using bootstrap)
2. Deploy all infrastructure with Terraform
3. Install AWS Load Balancer Controller
4. Deploy all 5 microservices

### Option 2: Manual Step-by-Step

#### Step 1: Create Backend (First Time Only)
```bash
# Use bootstrap to create S3 buckets
cd bootstrap
terraform init
terraform apply -auto-approve
cd ..
```

**Note:** Uses S3-native state locking (`use_lockfile = true`). No DynamoDB needed.

#### Step 2: Deploy Infrastructure
```bash
cd environments/prod
terraform init
terraform plan
terraform apply -auto-approve
```

⏱️ **Takes 20-30 minutes**

#### Step 3: Deploy Microservices
```bash
./../../scripts/deploy-microservices.sh
```

## 📋 What Gets Deployed

### Infrastructure Components
- ✅ VPC with 3 AZs (public + private subnets)
- ✅ NAT Gateways (3)
- ✅ VPC Endpoints (S3, ECR, Secrets Manager, CloudWatch, STS, KMS)
- ✅ EKS Cluster (Kubernetes 1.31)
- ✅ Aurora PostgreSQL Serverless v2 (2 instances)
- ✅ ElastiCache Redis (2 nodes with replication)
- ✅ Application Load Balancer
- ✅ CloudWatch Log Groups

### Microservices (All 5)
| Service | Replicas | CPU | Memory | IRSA Permissions |
|---------|----------|-----|--------|------------------|
| User Service | 3 | 0.5 | 1GB | S3, RDS, Secrets |
| Order Service | 2 | 1.0 | 2GB | SQS, SNS, DynamoDB |
| Payment Service | 2 | 0.5 | 1GB | Secrets, KMS, CloudWatch |
| Notification Service | 2 | 0.25 | 512MB | SES, SNS, SQS |
| Analytics Service | 2 | 2.0 | 4GB | S3, Athena, Glue, Redshift |

## 🔍 Verification Steps

### 1. Check Cluster
```bash
kubectl get nodes
kubectl get pods -A
```

### 2. Check Services
```bash
kubectl get svc --all-namespaces
```

### 3. Check Ingress
```bash
kubectl get ingress -n default
kubectl describe ingress microservices-ingress -n default
```

### 4. Get ALB DNS
```bash
ALB_DNS=$(kubectl get ingress microservices-ingress -n default -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo $ALB_DNS
```

### 5. Test Endpoints
```bash
curl http://${ALB_DNS}/api/users/health
curl http://${ALB_DNS}/api/orders/health
curl http://${ALB_DNS}/api/payments/health
curl http://${ALB_DNS}/api/notifications/health
curl http://${ALB_DNS}/api/analytics/health
```

## 📊 Monitoring

### View Logs
```bash
# User Service
kubectl logs -n user-service -l app=user-service --tail=50 -f

# Order Service
kubectl logs -n order-service -l app=order-service --tail=50 -f

# All services
kubectl logs -n user-service -l app=user-service --tail=20
kubectl logs -n order-service -l app=order-service --tail=20
kubectl logs -n payment-service -l app=payment-service --tail=20
kubectl logs -n notification-service -l app=notification-service --tail=20
kubectl logs -n analytics-service -l app=analytics-service --tail=20
```

### Resource Usage
```bash
kubectl top pods -A
```

### Events
```bash
kubectl get events -A --sort-by='.lastTimestamp'
```

## 🔧 Troubleshooting

### Pods Not Starting

**Issue**: Pods stuck in `Pending` state

**Solution**:
```bash
# Check Fargate profile
kubectl describe pod <pod-name> -n <namespace>

# Verify profiles exist
aws eks list-fargate-profiles --cluster-name eks-fargate-microservices-prod
```

### IRSA Not Working

**Issue**: Pods can't access AWS resources

**Solution**:
```bash
# Check service account annotation
kubectl describe sa user-service-sa -n user-service

# Verify OIDC provider
aws eks describe-cluster --name eks-fargate-microservices-prod \
  --query "cluster.identity.oidc.issuer" --output text

# Check pod environment
kubectl exec -n user-service <pod-name> -- env | grep AWS
```

### ALB Not Created

**Issue**: Ingress has no address

**Solution**:
```bash
# Check ALB Controller
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller

# Check ingress events
kubectl describe ingress microservices-ingress -n default
```

### Database Connection Issues

**Issue**: Services can't connect to RDS

**Solution**:
```bash
# Get RDS endpoint
terraform output rds_cluster_endpoint

# Check security group
aws ec2 describe-security-groups --filters "Name=tag:Name,Values=*rds*"

# Test from pod
kubectl exec -n user-service <pod-name> -- nc -zv <rds-endpoint> 5432
```

## 🧹 Cleanup

### Delete Everything
```bash
cd environments/prod

# Delete Kubernetes resources
kubectl delete -f ../../kubernetes/manifests/

# Wait for ALB to be deleted (check AWS console)

# Destroy infrastructure
terraform destroy -auto-approve
```

### Delete Backend (Optional)
```bash
# Delete S3 buckets using bootstrap
cd bootstrap
terraform destroy -auto-approve
```

## 💡 Tips

### Scale Services
```bash
# Scale user service to 5 replicas
kubectl scale deployment user-service -n user-service --replicas=5

# Verify
kubectl get pods -n user-service
```

### Update Service Image
```bash
# Update image
kubectl set image deployment/user-service user-service=myapp:v2 -n user-service

# Check rollout status
kubectl rollout status deployment/user-service -n user-service
```

### View Service Accounts
```bash
kubectl get sa -A | grep "\-sa"
```

### Access Secrets
```bash
# From pod
kubectl exec -n user-service <pod-name> -- \
  aws secretsmanager get-secret-value \
  --secret-id <secret-arn> \
  --query SecretString \
  --output text
```

## 📞 Support

For issues or questions:
1. Check the main [README.md](../README.md)
2. Review Terraform outputs: `terraform output`
3. Check AWS CloudWatch logs
4. Review pod logs: `kubectl logs -n <namespace> <pod-name>`

## 🎯 Next Steps

1. **Replace Demo Images**: Update container images in manifests
2. **Configure Domain**: Add Route53 DNS and ACM certificate
3. **Enable HTTPS**: Add certificate ARN to ALB
4. **Setup CI/CD**: Integrate with GitHub Actions or GitLab CI
5. **Add Monitoring**: Deploy Prometheus/Grafana
6. **Configure Autoscaling**: Add HPA for pods

---

**Happy Deploying! 🚀**
