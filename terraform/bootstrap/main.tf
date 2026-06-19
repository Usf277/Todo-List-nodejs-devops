provider "aws" {
  region = "us-east-1"
}

# S3 bucket to store the main Terraform state file
resource "aws_s3_bucket" "tfstate" {
  bucket        = "todo-list-tfstate-890742564852"
  force_destroy = false

  tags = {
    Name = "todo-list-tfstate"
  }
}

# Enable versioning so every state update is recoverable
resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Encrypt state at rest — state files contain secrets (IAM keys, IPs)
resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block all public access to the state bucket
resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket                  = aws_s3_bucket.tfstate.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# DynamoDB table for state locking — prevents concurrent applies
resource "aws_dynamodb_table" "tfstate_lock" {
  name         = "todo-list-tfstate-lock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name = "todo-list-tfstate-lock"
  }
}

output "bucket_name" {
  value = aws_s3_bucket.tfstate.bucket
}

output "dynamodb_table" {
  value = aws_dynamodb_table.tfstate_lock.name
}
