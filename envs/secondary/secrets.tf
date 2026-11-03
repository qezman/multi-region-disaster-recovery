# secondary's own DB connection details, pointing at its read replica

locals {
  # a replica shares the source DB's credentials, so the password comes from primary
  db_password = try(data.terraform_remote_state.primary.outputs.db_password, "")
}

resource "aws_secretsmanager_secret" "db" {
  name_prefix             = "${var.project}/${var.environment}/database-url-"
  kms_key_id              = module.database.kms_key_arn
  recovery_window_in_days = 0 # deleted immediately on destroy
}

resource "aws_secretsmanager_secret_version" "db" {
  secret_id = aws_secretsmanager_secret.db.id
  secret_string = jsonencode({
    username = "dbadmin"
    password = local.db_password
    host     = module.database.db_address # this region's replica, not primary
    port     = 5432
    dbname   = "transfers"
    url      = "postgres://dbadmin:${local.db_password}@${module.database.db_endpoint}/transfers"
  })

  lifecycle {
    precondition {
      condition     = local.db_password != ""
      error_message = "Primary's db_password output is missing. Apply envs/primary first, then secondary."
    }
  }
}
