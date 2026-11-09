# DB connection details for primary's tasks (secondary keeps its own)
# name_prefix gives each build a new name, so rebuilds never hit a name AWS is still holding
resource "aws_secretsmanager_secret" "db" {
  name_prefix             = "${var.project}/${var.environment}/database-url-"
  kms_key_id              = module.database.kms_key_arn
  recovery_window_in_days = 0 # deleted immediately on destroy
}

resource "aws_secretsmanager_secret_version" "db" {
  secret_id = aws_secretsmanager_secret.db.id
  secret_string = jsonencode({
    username = "dbadmin"
    password = module.database.db_password
    host     = module.database.db_address # hostname only; db_endpoint is host:port
    port     = 5432
    dbname   = "transfers"
    url      = "postgres://dbadmin:${module.database.db_password}@${module.database.db_endpoint}/transfers?sslmode=verify-full" # Bridge's image ships the RDS CA
  })
}
