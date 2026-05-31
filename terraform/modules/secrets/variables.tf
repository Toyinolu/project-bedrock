variable "mysql_endpoint" {
  type = string
}

variable "mysql_username" {
  type = string
}

variable "mysql_password" {
  type      = string
  sensitive = true
}

variable "postgres_endpoint" {
  type = string
}

variable "postgres_username" {
  type = string
}

variable "postgres_password" {
  type      = string
  sensitive = true
}
