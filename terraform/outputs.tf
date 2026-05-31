# ── Required by grading script ──────────────────────────────────────────────
output "cluster_endpoint" {
  description = "EKS cluster API server endpoint"
  value       = module.eks.cluster_endpoint
}

output "cluster_name" {
  description = "EKS cluster name"
  value       = var.cluster_name
}

output "region" {
  description = "AWS region"
  value       = var.region
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "assets_bucket_name" {
  description = "S3 assets bucket name"
  value       = module.serverless.assets_bucket_name
}

# ── Developer access credentials ────────────────────────────────────────────
output "bedrock_dev_view_access_key_id" {
  description = "Access Key ID for bedrock-dev-view IAM user"
  value       = aws_iam_access_key.bedrock_dev_view.id
  sensitive   = true
}

output "bedrock_dev_view_secret_access_key" {
  description = "Secret Access Key for bedrock-dev-view IAM user"
  value       = aws_iam_access_key.bedrock_dev_view.secret
  sensitive   = true
}

output "bedrock_dev_view_console_password" {
  description = "Console login password for bedrock-dev-view IAM user"
  value       = aws_iam_user_login_profile.bedrock_dev_view.password
  sensitive   = true
}

output "aws_console_login_url" {
  description = "AWS Console login URL for bedrock-dev-view"
  value       = "https://${data.aws_caller_identity.current.account_id}.signin.aws.amazon.com/console"
}

# ── Operational outputs ──────────────────────────────────────────────────────
output "rds_mysql_endpoint" {
  description = "RDS MySQL endpoint (host:port)"
  value       = module.rds.mysql_endpoint
}

output "rds_postgres_endpoint" {
  description = "RDS PostgreSQL endpoint (host:port)"
  value       = module.rds.postgres_endpoint
}

output "dynamodb_table_name" {
  description = "DynamoDB carts table name"
  value       = module.dynamodb.table_name
}

output "eks_oidc_provider_arn" {
  description = "EKS OIDC provider ARN (for IRSA)"
  value       = module.eks.oidc_provider_arn
}

output "cloudwatch_control_plane_log_group" {
  description = "CloudWatch log group for EKS control plane"
  value       = "/aws/eks/${var.cluster_name}/cluster"
}

output "cloudwatch_app_log_group" {
  description = "CloudWatch log group for application container logs"
  value       = "/aws/containerinsights/${var.cluster_name}/application"
}

output "app_url" {
  description = "URL to access the running Retail Store application"
  value       = module.k8s.app_url
}
