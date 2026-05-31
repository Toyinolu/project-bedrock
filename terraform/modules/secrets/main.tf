resource "aws_secretsmanager_secret" "mysql" {
  name                    = "project-bedrock/mysql-credentials"
  recovery_window_in_days = 0
  tags                    = { Name = "project-bedrock-mysql-credentials" }
}

resource "aws_secretsmanager_secret_version" "mysql" {
  secret_id = aws_secretsmanager_secret.mysql.id
  secret_string = jsonencode({
    username = var.mysql_username
    password = var.mysql_password
    host     = split(":", var.mysql_endpoint)[0]
    port     = 3306
    dbname   = "catalog"
    endpoint = var.mysql_endpoint
  })
}

resource "aws_secretsmanager_secret" "postgres" {
  name                    = "project-bedrock/postgres-credentials"
  recovery_window_in_days = 0
  tags                    = { Name = "project-bedrock-postgres-credentials" }
}

resource "aws_secretsmanager_secret_version" "postgres" {
  secret_id = aws_secretsmanager_secret.postgres.id
  secret_string = jsonencode({
    username = var.postgres_username
    password = var.postgres_password
    host     = split(":", var.postgres_endpoint)[0]
    port     = 5432
    dbname   = "orders"
    endpoint = var.postgres_endpoint
  })
}
