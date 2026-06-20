output "cluster_name" {
  value = aws_eks_cluster.main.name
}

output "cluster_endpoint" {
  value = aws_eks_cluster.main.endpoint
}

output "kubeconfig_command" {
  value = "aws eks update-kubeconfig --region ${var.region} --name ${aws_eks_cluster.main.name}"
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
