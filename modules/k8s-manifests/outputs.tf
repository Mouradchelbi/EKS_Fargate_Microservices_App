output "manifests_directory" {
  description = "Directory containing generated Kubernetes manifests"
  value       = var.output_dir
}

output "user_service_manifest_path" {
  description = "Path to generated user service manifest"
  value       = local_file.user_service_manifest.filename
}

output "order_service_manifest_path" {
  description = "Path to generated order service manifest"
  value       = local_file.order_service_manifest.filename
}

output "payment_service_manifest_path" {
  description = "Path to generated payment service manifest"
  value       = local_file.payment_service_manifest.filename
}

output "notification_service_manifest_path" {
  description = "Path to generated notification service manifest"
  value       = local_file.notification_service_manifest.filename
}

output "analytics_service_manifest_path" {
  description = "Path to generated analytics service manifest"
  value       = local_file.analytics_service_manifest.filename
}
