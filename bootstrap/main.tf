terraform {
  required_version = ">= 1.5"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

#=============================================================================
# S3 Bucket for Dev Environment State
#=============================================================================
resource "aws_s3_bucket" "tfstate_dev" {
  bucket = "eks-fargate-microservices-tfstate-dev"
  
  tags = {
    Name        = "Terraform State - Dev"
    Environment = "dev"
    Purpose     = "terraform-state"
    ManagedBy   = "Terraform"
  }
}

resource "aws_s3_bucket_versioning" "tfstate_dev" {
  bucket = aws_s3_bucket.tfstate_dev.id
  
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate_dev" {
  bucket = aws_s3_bucket.tfstate_dev.id
  
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "tfstate_dev" {
  bucket = aws_s3_bucket.tfstate_dev.id
  
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

#=============================================================================
# S3 Bucket for Staging Environment State
#=============================================================================
resource "aws_s3_bucket" "tfstate_staging" {
  bucket = "eks-fargate-microservices-tfstate-staging"
  
  tags = {
    Name        = "Terraform State - Staging"
    Environment = "staging"
    Purpose     = "terraform-state"
    ManagedBy   = "Terraform"
  }
}

resource "aws_s3_bucket_versioning" "tfstate_staging" {
  bucket = aws_s3_bucket.tfstate_staging.id
  
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate_staging" {
  bucket = aws_s3_bucket.tfstate_staging.id
  
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "tfstate_staging" {
  bucket = aws_s3_bucket.tfstate_staging.id
  
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

#=============================================================================
# S3 Bucket for Prod Environment State
#=============================================================================
resource "aws_s3_bucket" "tfstate_prod" {
  bucket = "eks-fargate-microservices-tfstate-prod"
  
  tags = {
    Name        = "Terraform State - Prod"
    Environment = "prod"
    Purpose     = "terraform-state"
    ManagedBy   = "Terraform"
  }
}

resource "aws_s3_bucket_versioning" "tfstate_prod" {
  bucket = aws_s3_bucket.tfstate_prod.id
  
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate_prod" {
  bucket = aws_s3_bucket.tfstate_prod.id
  
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "tfstate_prod" {
  bucket = aws_s3_bucket.tfstate_prod.id
  
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
