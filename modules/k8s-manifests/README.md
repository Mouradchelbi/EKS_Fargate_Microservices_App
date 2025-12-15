# Kubernetes Manifests Generation Module - README

This module provides **two approaches** for managing Kubernetes manifests with Terraform outputs.

---

## **Approach 1: Script-Based (Recommended for Beginners)**

### How It Works
1. Terraform creates infrastructure and outputs values
2. Run `update-manifests.sh` script
3. Script reads Terraform outputs and replaces placeholders
4. Generates ready-to-deploy manifests
5. Optionally applies to Kubernetes

### Usage

```bash
# After terraform apply
cd scripts
./update-manifests.sh prod

# Review generated manifests
ls -la /tmp/k8s-manifests-*/

# Apply to Kubernetes
kubectl apply -f /tmp/k8s-manifests-*/*.yaml
```

### Pros
- ✅ Simple and transparent
- ✅ Works with any K8s cluster
- ✅ Manual review before apply
- ✅ No additional Terraform providers needed

### Cons
- ❌ Requires manual script execution
- ❌ Separate step from Terraform workflow

---

## **Approach 2: Terraform Kubernetes Provider (Advanced)**

### How It Works
1. Terraform creates infrastructure
2. Terraform directly creates Kubernetes resources
3. Everything managed in one `terraform apply`

### Implementation

Add to your `environments/prod/main.tf`:

```hcl
# Configure Kubernetes provider
data "aws_eks_cluster" "cluster" {
  name = module.eks.cluster_name
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_name
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

# Deploy user service
resource "kubernetes_namespace" "user_service" {
  metadata {
    name = "user-service"
    labels = {
      name = "user-service"
    }
  }
}

resource "kubernetes_service_account" "user_service" {
  metadata {
    name      = "user-service-sa"
    namespace = kubernetes_namespace.user_service.metadata[0].name
    annotations = {
      "eks.amazonaws.com/role-arn" = module.user_service_irsa.role_arn
    }
  }
}

resource "kubernetes_deployment" "user_service" {
  metadata {
    name      = "user-service"
    namespace = kubernetes_namespace.user_service.metadata[0].name
    labels = {
      app = "user-service"
    }
  }

  spec {
    replicas = 3

    selector {
      match_labels = {
        app = "user-service"
      }
    }

    template {
      metadata {
        labels = {
          app = "user-service"
        }
      }

      spec {
        service_account_name = kubernetes_service_account.user_service.metadata[0].name

        container {
          name  = "user-service"
          image = "${module.ecr_user_service.repository_url}:latest"

          port {
            container_port = 8080
            name          = "http"
          }

          resources {
            requests = {
              cpu    = "500m"
              memory = "1Gi"
            }
            limits = {
              cpu    = "500m"
              memory = "1Gi"
            }
          }

          env {
            name  = "SERVICE_NAME"
            value = "user-service"
          }

          env {
            name  = "DB_SECRET_ARN"
            value = module.rds.secret_arn
          }

          env {
            name  = "REDIS_ENDPOINT"
            value = module.elasticache.endpoint
          }

          env {
            name  = "AWS_REGION"
            value = var.aws_region
          }

          liveness_probe {
            http_get {
              path = "/health"
              port = 8080
            }
            initial_delay_seconds = 30
            period_seconds       = 10
          }

          readiness_probe {
            http_get {
              path = "/ready"
              port = 8080
            }
            initial_delay_seconds = 5
            period_seconds       = 5
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "user_service" {
  metadata {
    name      = "user-service"
    namespace = kubernetes_namespace.user_service.metadata[0].name
    labels = {
      app = "user-service"
    }
  }

  spec {
    type = "ClusterIP"

    port {
      port        = 80
      target_port = 8080
      protocol    = "TCP"
      name        = "http"
    }

    selector = {
      app = "user-service"
    }
  }
}
```

### Pros
- ✅ Single `terraform apply` deploys everything
- ✅ Infrastructure and apps in sync
- ✅ Terraform state tracks K8s resources
- ✅ Automatic dependency management

### Cons
- ❌ More complex Terraform code
- ❌ Requires Kubernetes provider configuration
- ❌ Harder to debug K8s issues
- ❌ Mixing infrastructure and application concerns

---

## **Approach 3: Helm Charts (Production Best Practice)**

### How It Works
1. Create Helm chart for each microservice
2. Use Terraform to install Helm releases
3. Pass values from Terraform outputs

### Example Structure

```
helm-charts/
├── user-service/
│   ├── Chart.yaml
│   ├── values.yaml
│   └── templates/
│       ├── deployment.yaml
│       ├── service.yaml
│       └── serviceaccount.yaml
```

### Terraform Implementation

```hcl
provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.cluster.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}

resource "helm_release" "user_service" {
  name      = "user-service"
  chart     = "../../helm-charts/user-service"
  namespace = "user-service"
  create_namespace = true

  set {
    name  = "image.repository"
    value = module.ecr_user_service.repository_url
  }

  set {
    name  = "image.tag"
    value = "latest"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.user_service_irsa.role_arn
  }

  set {
    name  = "env.DB_SECRET_ARN"
    value = module.rds.secret_arn
  }

  set {
    name  = "env.REDIS_ENDPOINT"
    value = module.elasticache.endpoint
  }
}
```

### Pros
- ✅ Industry standard for K8s apps
- ✅ Reusable charts across environments
- ✅ Easy rollbacks and upgrades
- ✅ Template engine for complex scenarios

### Cons
- ❌ Learning curve for Helm
- ❌ Additional tooling required
- ❌ More files to maintain

---

## **Recommendation by Use Case**

| Use Case | Recommended Approach |
|----------|---------------------|
| **Learning/Testing** | Script-based (Approach 1) |
| **Small Teams** | Script-based (Approach 1) |
| **CI/CD Pipeline** | Terraform K8s Provider (Approach 2) |
| **Production/Enterprise** | Helm Charts (Approach 3) |
| **Multi-environment** | Helm Charts (Approach 3) |

---

## **What's Included in This Module**

The `k8s-manifests` module generates manifest files using Terraform's `templatefile()` function:

```hcl
# In environments/prod/main.tf
module "k8s_manifests" {
  source = "../../modules/k8s-manifests"
  
  # Pass all IRSA role ARNs
  user_service_irsa_role_arn         = module.user_service_irsa.role_arn
  order_service_irsa_role_arn        = module.order_service_irsa.role_arn
  payment_service_irsa_role_arn      = module.payment_service_irsa.role_arn
  notification_service_irsa_role_arn = module.notification_service_irsa.role_arn
  analytics_service_irsa_role_arn    = module.analytics_service_irsa.role_arn
  
  # Pass ECR URLs
  user_service_ecr_url         = module.ecr_user_service.repository_url
  order_service_ecr_url        = module.ecr_order_service.repository_url
  payment_service_ecr_url      = module.ecr_payment_service.repository_url
  notification_service_ecr_url = module.ecr_notification_service.repository_url
  analytics_service_ecr_url    = module.ecr_analytics_service.repository_url
  
  # Pass other values
  rds_secret_arn = module.rds.secret_arn
  redis_endpoint = module.elasticache.endpoint
  aws_region     = var.aws_region
}
```

Then run:
```bash
terraform apply  # Generates manifests
kubectl apply -f kubernetes/manifests/generated/
```

---

## **Quick Start (Recommended)**

For this project, use the **script approach**:

1. Deploy infrastructure: `terraform apply`
2. Run script: `./scripts/update-manifests.sh prod`
3. Review manifests in `/tmp/`
4. Deploy: `kubectl apply -f /tmp/k8s-manifests-*/`

Simple, transparent, and works perfectly! 🚀
