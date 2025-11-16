# ECR Repository for CI/CD Pipeline
# This creates the container registry for the nginx demo application

resource "aws_ecr_repository" "nginx_demo" {
  name                 = "nginx-demo-app"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = merge(
    local.tags,
    {
      Name        = "nginx-demo-app"
      Purpose     = "CI/CD Pipeline Demo"
      ManagedBy   = "Terraform"
    }
  )
}

# Lifecycle policy to keep only recent images
resource "aws_ecr_lifecycle_policy" "nginx_demo" {
  repository = aws_ecr_repository.nginx_demo.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["main-", "sha-"]
          countType     = "imageCountMoreThan"
          countNumber   = 10
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Keep 'latest' tag"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["latest"]
          countType     = "imageCountMoreThan"
          countNumber   = 1
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 3
        description  = "Remove untagged images after 1 day"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 1
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# GitHub OIDC Provider
resource "aws_iam_openid_connect_provider" "github_actions" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com",
  ]

  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd"
  ]

  tags = merge(
    local.tags,
    {
      Name      = "github-actions-oidc"
      Purpose   = "GitHub Actions OIDC"
      ManagedBy = "Terraform"
    }
  )
}

# IAM Role for GitHub Actions
resource "aws_iam_role" "github_actions" {
  name               = "GitHubActionsECRRole"
  path               = "/cicd/"
  description        = "Role for GitHub Actions to push/pull ECR images via OIDC"
  assume_role_policy = data.aws_iam_policy_document.github_actions_assume_role.json

  tags = merge(
    local.tags,
    {
      Name      = "GitHubActionsECRRole"
      Purpose   = "CI/CD GitHub Actions"
      ManagedBy = "Terraform"
    }
  )
}

# Trust policy for GitHub Actions OIDC
data "aws_iam_policy_document" "github_actions_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github_actions.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:horaceheaven/argo-rollouts-app:*"]
    }
  }
}

# IAM Policy for ECR Push/Pull
resource "aws_iam_policy" "github_actions_ecr" {
  name        = "GitHubActionsECRPolicy"
  path        = "/cicd/"
  description = "Allows GitHub Actions to push/pull images to/from ECR"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
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
          "ecr:PutImage",
          "ecr:StartImageScan",
          "ecr:DescribeImageScanFindings"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "sts:GetCallerIdentity"
        ]
        Resource = "*"
      }
    ]
  })

  tags = local.tags
}

# Attach policy to role
resource "aws_iam_role_policy_attachment" "github_actions_ecr" {
  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.github_actions_ecr.arn
}

# Allow EKS nodes to pull from ECR
resource "aws_iam_role_policy_attachment" "eks_ecr_pull" {
  for_each = module.eks.eks_managed_node_groups

  role       = each.value.iam_role_name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

