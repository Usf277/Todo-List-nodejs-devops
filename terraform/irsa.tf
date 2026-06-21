# IRSA (IAM Roles for Service Accounts) — lets pods assume IAM roles directly
# via STS instead of using the EC2 instance metadata service.
#
# Required for EBS CSI driver: the controller pod needs EC2 API access to
# create/attach/delete EBS volumes. IMDSv2 hop limit on EKS nodes defaults
# to 1, so pods (one hop from the host) cannot reach 169.254.169.254.
# IRSA bypasses the metadata service entirely — the pod gets a token from
# the Kubernetes API, exchanges it at STS, and gets short-lived credentials.

data "tls_certificate" "eks_oidc" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks_oidc.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

locals {
  oidc_issuer = replace(aws_iam_openid_connect_provider.eks.url, "https://", "")
}

# IAM role that only the EBS CSI controller ServiceAccount can assume
resource "aws_iam_role" "ebs_csi" {
  name = "todo-list-ebs-csi-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.eks.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${local.oidc_issuer}:sub" = "system:serviceaccount:kube-system:ebs-csi-controller-sa"
          "${local.oidc_issuer}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ebs_csi_irsa" {
  role       = aws_iam_role.ebs_csi.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}
