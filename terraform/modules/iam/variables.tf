variable "student_id"        { type = string }
variable "cluster_name"      { type = string }
variable "github_org"        { type = string }
variable "github_repo"       { type = string }
variable "oidc_provider_arn" { type = string }
variable "oidc_provider_url" { type = string }
variable "assets_bucket_arn" { type = string }
variable "domain_name" {
  type    = string
  default = ""
}

variable "dynamodb_table_name" {
  type    = string
  default = "retail-store-carts"
}
