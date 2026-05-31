resource "random_password" "mysql" {
  length  = 16
  special = false
}

resource "random_password" "postgres" {
  length  = 16
  special = false
}

# ── DB Subnet Group ───────────────────────────────────────────────────────────
resource "aws_db_subnet_group" "main" {
  name       = "project-bedrock-db-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = { Name = "project-bedrock-db-subnet-group" }
}

# ── Security Groups ───────────────────────────────────────────────────────────
resource "aws_security_group" "mysql" {
  name        = "project-bedrock-rds-mysql-sg"
  description = "Allow MySQL from EKS nodes only"
  vpc_id      = var.vpc_id

  ingress {
    description     = "MySQL from EKS nodes"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [var.eks_node_sg_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "project-bedrock-rds-mysql-sg" }
}

resource "aws_security_group" "postgres" {
  name        = "project-bedrock-rds-postgres-sg"
  description = "Allow PostgreSQL from EKS nodes only"
  vpc_id      = var.vpc_id

  ingress {
    description     = "PostgreSQL from EKS nodes"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.eks_node_sg_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "project-bedrock-rds-postgres-sg" }
}

# ── RDS MySQL ─────────────────────────────────────────────────────────────────
resource "aws_db_instance" "mysql" {
  identifier             = "project-bedrock-mysql"
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  db_name                = "catalog"
  username               = var.db_master_username
  password               = random_password.mysql.result
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.mysql.id]
  publicly_accessible    = false
  skip_final_snapshot    = true
  multi_az               = false
  storage_encrypted      = true

  tags = { Name = "project-bedrock-mysql" }
}

# ── RDS PostgreSQL ────────────────────────────────────────────────────────────
resource "aws_db_instance" "postgres" {
  identifier             = "project-bedrock-postgres"
  engine                 = "postgres"
  engine_version         = "15"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  db_name                = "orders"
  username               = var.db_master_username
  password               = random_password.postgres.result
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.postgres.id]
  publicly_accessible    = false
  skip_final_snapshot    = true
  multi_az               = false
  storage_encrypted      = true

  tags = { Name = "project-bedrock-postgres" }
}
