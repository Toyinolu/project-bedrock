data "aws_caller_identity" "current" {}

locals {
  oidc_host = replace(var.oidc_provider_url, "https://", "")
}

# ── AWS Load Balancer Controller IRSA Role ────────────────────────────────────
data "aws_iam_policy_document" "lb_controller_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:sub"
      values   = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lb_controller" {
  name               = "project-bedrock-lb-controller-role"
  assume_role_policy = data.aws_iam_policy_document.lb_controller_assume.json
  tags               = { Name = "project-bedrock-lb-controller-role" }
}

resource "aws_iam_policy" "lb_controller" {
  name   = "project-bedrock-lb-controller-policy"
  policy = file("${path.module}/lb_controller_iam_policy.json")
  tags   = { Name = "project-bedrock-lb-controller-policy" }
}

resource "aws_iam_role_policy_attachment" "lb_controller" {
  role       = aws_iam_role.lb_controller.name
  policy_arn = aws_iam_policy.lb_controller.arn
}

# ── CloudWatch Observability IRSA Role ────────────────────────────────────────
data "aws_iam_policy_document" "cloudwatch_agent_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:sub"
      values   = ["system:serviceaccount:amazon-cloudwatch:cloudwatch-agent"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "cloudwatch_agent" {
  name               = "project-bedrock-cloudwatch-agent-role"
  assume_role_policy = data.aws_iam_policy_document.cloudwatch_agent_assume.json
  tags               = { Name = "project-bedrock-cloudwatch-agent-role" }
}

resource "aws_iam_role_policy_attachment" "cloudwatch_agent" {
  role       = aws_iam_role.cloudwatch_agent.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# ── Cart Service IRSA Role (DynamoDB) ─────────────────────────────────────────
data "aws_iam_policy_document" "cart_irsa_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:sub"
      values   = ["system:serviceaccount:retail-app:carts"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "cart_irsa" {
  name               = "project-bedrock-cart-service-role"
  assume_role_policy = data.aws_iam_policy_document.cart_irsa_assume.json
  tags               = { Name = "project-bedrock-cart-service-role" }
}

resource "aws_iam_role_policy" "cart_dynamodb" {
  name = "cart-dynamodb-access"
  role = aws_iam_role.cart_irsa.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:UpdateItem",
        "dynamodb:DeleteItem", "dynamodb:Query", "dynamodb:Scan", "dynamodb:DescribeTable"
      ]
      Resource = [
        "arn:aws:dynamodb:us-east-1:${data.aws_caller_identity.current.account_id}:table/${var.dynamodb_table_name}",
        "arn:aws:dynamodb:us-east-1:${data.aws_caller_identity.current.account_id}:table/${var.dynamodb_table_name}/index/*"
      ]
    }]
  })
}

# ── Lambda Execution Role ─────────────────────────────────────────────────────
resource "aws_iam_role" "lambda_exec" {
  name = "project-bedrock-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Effect = "Allow", Principal = { Service = "lambda.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })

  tags = { Name = "project-bedrock-lambda-role" }
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "lambda_s3" {
  name = "lambda-s3-get"
  role = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "s3:GetObject"
      Resource = "${var.assets_bucket_arn}/*"
    }]
  })
}

# ── GitHub Actions OIDC (only created when github_org is set) ─────────────────
resource "aws_iam_openid_connect_provider" "github" {
  count           = var.github_org != "" ? 1 : 0
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
  tags            = { Name = "github-actions-oidc" }
}

resource "aws_iam_role" "github_actions" {
  count = var.github_org != "" ? 1 : 0
  name  = "project-bedrock-github-actions-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.github[0].arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringLike   = { "token.actions.githubusercontent.com:sub" = "repo:${var.github_org}/${var.github_repo}:*" }
        StringEquals = { "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com" }
      }
    }]
  })

  tags = { Name = "project-bedrock-github-actions-role" }
}

resource "aws_iam_role_policy_attachment" "github_actions_admin" {
  count      = var.github_org != "" ? 1 : 0
  role       = aws_iam_role.github_actions[0].name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# ── ACM Certificate (Bonus 5.2) ───────────────────────────────────────────────
resource "aws_acm_certificate" "app" {
  count             = var.domain_name != "" ? 1 : 0
  domain_name       = var.domain_name
  subject_alternative_names = ["*.${var.domain_name}"]
  validation_method = "DNS"

  lifecycle { create_before_destroy = true }

  tags = { Name = "project-bedrock-acm-cert" }
}
