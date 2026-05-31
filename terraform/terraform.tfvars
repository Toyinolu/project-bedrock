# Non-sensitive values only — never put passwords or secrets here
region             = "us-east-1"
cluster_name       = "project-bedrock-cluster"
eks_version        = "1.35"   # Latest GA in us-east-1 as of deployment date
student_id         = "alt-soe-025-3783"
vpc_cidr           = "10.0.0.0/16"
node_instance_type = "t3.small"
node_desired_size  = 3
node_min_size      = 2
node_max_size      = 4
db_master_username = "admin"
github_org         = "Toyinolu"
github_repo        = "project-bedrock"
domain_name        = ""       # Set to your registered domain (Bonus 5.2)
