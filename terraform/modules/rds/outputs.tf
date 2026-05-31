output "mysql_endpoint"    { value = "${aws_db_instance.mysql.address}:3306" }
output "mysql_password"    {
  value     = random_password.mysql.result
  sensitive = true
}
output "postgres_endpoint" { value = "${aws_db_instance.postgres.address}:5432" }
output "postgres_password" {
  value     = random_password.postgres.result
  sensitive = true
}
