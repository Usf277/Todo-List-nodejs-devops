terraform {
  backend "s3" {
    bucket         = "todo-list-tfstate-890742564852"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "todo-list-tfstate-lock"
    encrypt        = true
  }
}
