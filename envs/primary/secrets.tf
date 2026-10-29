resource "aws_secretsmanager_secret" "db" {
  name                    = "${var.project}/database-url"
  kms_key_id              = module.database.kms_key_arn
  recovery_window_in_days = 0 # allows immediate recreation without name conflicts

  replica {
    region     = "eu-central-1"
    kms_key_id = data.terraform_remote_state.secondary.outputs.kms_key_arn
  }
}

resource "aws_secretsmanager_secret_version" "db" {
  secret_id = aws_secretsmanager_secret.db.id
  secret_string = jsonencode({
    username = "dbadmin"
    password = module.database.db_password
    host     = module.database.db_endpoint
    port     = 5432
    dbname   = "transfers"
    url      = "postgres://dbadmin:${module.database.db_password}@${module.database.db_endpoint}/transfers"
  })
}