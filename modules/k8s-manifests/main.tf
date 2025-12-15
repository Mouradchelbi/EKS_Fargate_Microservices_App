# Generate Kubernetes manifests with Terraform outputs

resource "local_file" "user_service_manifest" {
  filename = "${var.output_dir}/user-service.yaml"
  content  = templatefile("${path.module}/templates/user-service.yaml.tpl", {
    irsa_role_arn    = var.user_service_irsa_role_arn
    ecr_image_url    = var.user_service_ecr_url
    rds_secret_arn   = var.rds_secret_arn
    redis_endpoint   = var.redis_endpoint
    aws_region       = var.aws_region
  })
}

resource "local_file" "order_service_manifest" {
  filename = "${var.output_dir}/order-service.yaml"
  content  = templatefile("${path.module}/templates/order-service.yaml.tpl", {
    irsa_role_arn  = var.order_service_irsa_role_arn
    ecr_image_url  = var.order_service_ecr_url
    rds_secret_arn = var.rds_secret_arn
    redis_endpoint = var.redis_endpoint
    aws_region     = var.aws_region
  })
}

resource "local_file" "payment_service_manifest" {
  filename = "${var.output_dir}/payment-service.yaml"
  content  = templatefile("${path.module}/templates/payment-service.yaml.tpl", {
    irsa_role_arn  = var.payment_service_irsa_role_arn
    ecr_image_url  = var.payment_service_ecr_url
    rds_secret_arn = var.rds_secret_arn
    redis_endpoint = var.redis_endpoint
    aws_region     = var.aws_region
  })
}

resource "local_file" "notification_service_manifest" {
  filename = "${var.output_dir}/notification-service.yaml"
  content  = templatefile("${path.module}/templates/notification-service.yaml.tpl", {
    irsa_role_arn = var.notification_service_irsa_role_arn
    ecr_image_url = var.notification_service_ecr_url
    aws_region    = var.aws_region
  })
}

resource "local_file" "analytics_service_manifest" {
  filename = "${var.output_dir}/analytics-service.yaml"
  content  = templatefile("${path.module}/templates/analytics-service.yaml.tpl", {
    irsa_role_arn  = var.analytics_service_irsa_role_arn
    ecr_image_url  = var.analytics_service_ecr_url
    rds_secret_arn = var.rds_secret_arn
    redis_endpoint = var.redis_endpoint
    aws_region     = var.aws_region
  })
}

resource "local_file" "ingress_manifest" {
  filename = "${var.output_dir}/ingress.yaml"
  content  = file("${path.module}/templates/ingress.yaml")
}
