variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "project-bedrock-cluster"
}

variable "eks_version" {
  description = "EKS Kubernetes version — must be >= 1.34 per project requirements"
  type        = string
  default     = "1.35"
}

variable "student_id" {
  description = "Student ID used to suffix unique resource names"
  type        = string
  default     = "alt-soe-025-3783"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "node_instance_type" {
  description = "EC2 instance type for EKS worker nodes"
  type        = string
  default     = "t3.small"
}

variable "node_desired_size" {
  description = "Desired number of EKS worker nodes"
  type        = number
  default     = 3
}

variable "node_min_size" {
  description = "Minimum number of EKS worker nodes"
  type        = number
  default     = 2
}

variable "node_max_size" {
  description = "Maximum number of EKS worker nodes"
  type        = number
  default     = 4
}

variable "db_master_username" {
  description = "Master username for RDS instances"
  type        = string
  default     = "admin"
}

variable "github_org" {
  description = "GitHub organization or username owning the repo"
  type        = string
  default     = ""
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
  default     = "project-bedrock"
}

variable "domain_name" {
  description = "Custom domain name for the application (Bonus 5.2)"
  type        = string
  default     = ""
}
