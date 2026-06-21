resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  role_arn = aws_iam_role.eks_cluster.arn
  version  = "1.30"

  vpc_config {
    subnet_ids             = [aws_subnet.public_a.id, aws_subnet.public_b.id]
    endpoint_public_access = true
  }

  access_config {
    authentication_mode = "API_AND_CONFIG_MAP"
  }

  depends_on = [aws_iam_role_policy_attachment.eks_cluster_policy]

  tags = {
    Name = var.cluster_name
  }
}

resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "todo-list-nodes"
  node_role_arn   = aws_iam_role.eks_node.arn
  subnet_ids      = [aws_subnet.public_a.id, aws_subnet.public_b.id]
  instance_types  = [var.node_instance_type]

  scaling_config {
    desired_size = 1
    min_size     = 1
    max_size     = 2
  }

  update_config {
    max_unavailable = 1
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.eks_ecr_read,
  ]

  tags = {
    Name = "todo-list-nodes"
  }
}

# Capture the IAM identity running terraform apply — needed for provisioner access entry
data "aws_caller_identity" "provisioner" {}

# Grant cluster-admin to whoever ran terraform apply (the provisioner/operator)
# In API_AND_CONFIG_MAP mode the cluster creator is NOT auto-granted kubectl access
resource "aws_eks_access_entry" "provisioner" {
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = data.aws_caller_identity.provisioner.arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "provisioner_admin" {
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = data.aws_caller_identity.provisioner.arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.provisioner]
}

# Grant the CI/CD IAM user cluster-admin access via the modern EKS API auth mode
resource "aws_eks_access_entry" "cicd" {
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = aws_iam_user.cicd_user.arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "cicd_admin" {
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = aws_iam_user.cicd_user.arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }
}
