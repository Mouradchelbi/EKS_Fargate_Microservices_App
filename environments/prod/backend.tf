terraform {
  backend "s3" {
    bucket       = "eks-fargate-microservices-tfstate-prod"
    key          = "prod/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
