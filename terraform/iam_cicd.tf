resource "aws_iam_user" "cicd_user" {
  name = "todo_cicd_user"
}

resource "aws_iam_access_key" "cicd_keys" {
  user = aws_iam_user.cicd_user.name
}

resource "aws_iam_user_policy" "cicd_policy" {
  name = "todo_cicd_policy"
  user = aws_iam_user.cicd_user.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ECR"
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:GetRepositoryPolicy",
          "ecr:DescribeRepositories",
          "ecr:ListImages",
          "ecr:DescribeImages",
          "ecr:BatchGetImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage"
        ]
        Resource = "*"
      },
      {
        Sid      = "EC2InstanceConnect"
        Effect   = "Allow"
        Action   = "ec2-instance-connect:SendSSHPublicKey"
        Resource = "*" # Restrict to specific ARN if strict security needed, but * is standard for dev setups
      },
      {
        Sid      = "EC2Describe"
        Effect   = "Allow"
        Action   = "ec2:DescribeInstances"
        Resource = "*"
      }
    ]
  })
}
