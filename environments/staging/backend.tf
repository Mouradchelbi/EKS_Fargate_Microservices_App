terraform {
  backend "s3" {
    bucket       = "eks-fargate-microservices-tfstate-staging"
    key          = "staging/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
