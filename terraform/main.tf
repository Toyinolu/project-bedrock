data "aws_caller_identity" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
}

# ── VPC ───────────────────────────────────────────────────────────────────────
module "vpc" {
  source       = "./modules/vpc"
  vpc_cidr     = var.vpc_cidr
  cluster_name = var.cluster_name
  azs          = slice(data.aws_availability_zones.available.names, 0, 2)
}

# ── EKS Base IAM (cluster + node roles — must exist before EKS cluster) ──────
# These resources have NO dependency on the EKS OIDC provider.
resource "aws_iam_role" "eks_cluster" {
  name = "project-bedrock-eks-cluster-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Effect = "Allow", Principal = { Service = "eks.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
  tags = { Name = "project-bedrock-eks-cluster-role" }
}
resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  role       = aws_iam_role.eks_cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role" "eks_node" {
  name = "project-bedrock-eks-node-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Effect = "Allow", Principal = { Service = "ec2.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
  tags = { Name = "project-bedrock-eks-node-role" }
}
resource "aws_iam_role_policy_attachment" "eks_node_worker" {
  role       = aws_iam_role.eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}
resource "aws_iam_role_policy_attachment" "eks_node_ecr" {
  role       = aws_iam_role.eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}
resource "aws_iam_role_policy_attachment" "eks_node_cni" {
  role       = aws_iam_role.eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}
resource "aws_iam_role_policy_attachment" "eks_node_cw" {
  role       = aws_iam_role.eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# bedrock-dev-view user (no OIDC dependency)
resource "aws_iam_user" "bedrock_dev_view" {
  name = "bedrock-dev-view"
  tags = { Name = "bedrock-dev-view" }
}
resource "aws_iam_user_policy_attachment" "bedrock_dev_readonly" {
  user       = aws_iam_user.bedrock_dev_view.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}
resource "aws_iam_user_login_profile" "bedrock_dev_view" {
  user                    = aws_iam_user.bedrock_dev_view.name
  password_reset_required = false
}
resource "aws_iam_access_key" "bedrock_dev_view" {
  user = aws_iam_user.bedrock_dev_view.name
}

# ── EKS Cluster ───────────────────────────────────────────────────────────────
module "eks" {
  source = "./modules/eks"

  cluster_name       = var.cluster_name
  eks_version        = var.eks_version
  private_subnet_ids = module.vpc.private_subnet_ids
  cluster_role_arn   = aws_iam_role.eks_cluster.arn
  node_role_arn      = aws_iam_role.eks_node.arn

  node_instance_type   = var.node_instance_type
  node_desired_size    = var.node_desired_size
  node_min_size        = var.node_min_size
  node_max_size        = var.node_max_size
  bedrock_dev_view_arn = aws_iam_user.bedrock_dev_view.arn

  depends_on = [
    module.vpc,
    aws_iam_role_policy_attachment.eks_cluster_policy,
    aws_iam_role_policy_attachment.eks_node_worker,
    aws_iam_role_policy_attachment.eks_node_ecr,
    aws_iam_role_policy_attachment.eks_node_cni,
  ]
}

# ── Serverless (S3 + Lambda) — independent, can run in parallel with EKS ─────
module "serverless" {
  source               = "./modules/serverless"
  student_id           = var.student_id
  bedrock_dev_view_arn = aws_iam_user.bedrock_dev_view.arn
  lambda_role_arn      = module.iam.lambda_role_arn

  depends_on = [module.iam]
}

# ── IAM IRSA roles (need EKS OIDC + assets bucket ARN) ───────────────────────
module "iam" {
  source            = "./modules/iam"
  student_id        = var.student_id
  cluster_name      = var.cluster_name
  github_org        = var.github_org
  github_repo       = var.github_repo
  domain_name       = var.domain_name
  oidc_provider_arn   = module.eks.oidc_provider_arn
  oidc_provider_url   = module.eks.oidc_provider_url
  assets_bucket_arn   = "arn:aws:s3:::bedrock-assets-${var.student_id}"
  dynamodb_table_name = module.dynamodb.table_name

  depends_on = [module.eks, module.dynamodb]
}

# ── bedrock-dev-view s3:PutObject on assets bucket ───────────────────────────
resource "aws_iam_user_policy" "bedrock_dev_s3_put" {
  name = "bedrock-dev-s3-putobject"
  user = aws_iam_user.bedrock_dev_view.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "s3:PutObject"
      Resource = "arn:aws:s3:::bedrock-assets-${var.student_id}/*"
    }]
  })
}

# ── RDS ───────────────────────────────────────────────────────────────────────
module "rds" {
  source             = "./modules/rds"
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  eks_node_sg_id     = module.eks.node_security_group_id
  db_master_username = var.db_master_username

  depends_on = [module.vpc, module.eks]
}

# ── DynamoDB ──────────────────────────────────────────────────────────────────
module "dynamodb" {
  source = "./modules/dynamodb"
}

# ── Secrets Manager ───────────────────────────────────────────────────────────
module "secrets" {
  source            = "./modules/secrets"
  mysql_endpoint    = module.rds.mysql_endpoint
  mysql_username    = module.rds.mysql_username
  mysql_password    = module.rds.mysql_password
  postgres_endpoint = module.rds.postgres_endpoint
  postgres_username = module.rds.postgres_username
  postgres_password = module.rds.postgres_password

  depends_on = [module.rds]
}

# ── CloudWatch Observability addon (needs IRSA from module.iam + cluster from module.eks) ──
resource "aws_eks_addon" "cloudwatch_observability" {
  cluster_name             = var.cluster_name
  addon_name               = "amazon-cloudwatch-observability"
  service_account_role_arn = module.iam.cloudwatch_agent_role_arn
  resolve_conflicts_on_update = "OVERWRITE"

  tags = { Name = "cloudwatch-observability" }

  depends_on = [module.eks, module.iam]
}

# ── Kubernetes (LB Controller + App + RBAC K8s resources) ────────────────────
module "k8s" {
  source                 = "./modules/k8s"
  cluster_name           = var.cluster_name
  lb_controller_role_arn = module.iam.lb_controller_role_arn
  cart_irsa_role_arn     = module.iam.cart_irsa_role_arn
  mysql_endpoint         = module.rds.mysql_endpoint
  mysql_password         = module.rds.mysql_password
  postgres_endpoint      = module.rds.postgres_endpoint
  postgres_password      = module.rds.postgres_password
  dynamodb_table_name    = module.dynamodb.table_name
  mysql_username         = module.rds.mysql_username
  postgres_username      = module.rds.postgres_username
  region                 = var.region
  domain_name            = var.domain_name
  acm_certificate_arn    = module.iam.acm_certificate_arn

  depends_on = [module.eks, module.rds, module.dynamodb, module.iam, module.serverless]
}
