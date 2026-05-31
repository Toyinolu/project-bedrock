variable "cluster_name" {
  type = string
}

variable "lb_controller_role_arn" {
  type = string
}

variable "cart_irsa_role_arn" {
  type = string
}

variable "mysql_endpoint" {
  type = string
}

variable "mysql_password" {
  type      = string
  sensitive = true
}

variable "postgres_endpoint" {
  type = string
}

variable "postgres_password" {
  type      = string
  sensitive = true
}

variable "dynamodb_table_name" {
  type = string
}

variable "mysql_username" {
  type    = string
  default = "admin"
}

variable "postgres_username" {
  type    = string
  default = "dbadmin"
}

variable "region" {
  type = string
}

variable "domain_name" {
  type    = string
  default = ""
}

variable "acm_certificate_arn" {
  type    = string
  default = ""
}
