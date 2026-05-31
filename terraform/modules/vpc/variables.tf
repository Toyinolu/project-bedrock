variable "vpc_cidr" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "azs" {
  type = list(string)
}
