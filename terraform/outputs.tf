output "public_ip" {
  value = aws_eip.lb.public_ip
}

output "mongo_private_ip" {
  value = aws_instance.mongo_server.private_ip
}

output "app_instance_id" {
  value = aws_instance.app_server.id
}

output "ecr_repository_url" {
  value = aws_ecr_repository.app_repo.repository_url
}

output "cicd_access_key_id" {
  value = aws_iam_access_key.cicd_keys.id
}

output "cicd_secret_access_key" {
  value     = aws_iam_access_key.cicd_keys.secret
  sensitive = true
}
