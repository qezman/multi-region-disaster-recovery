locals {
  is_replica = var.replicate_source_arn != null
}

# creates the database sg
resource "aws_security_group" "db" {
  name        = "${var.project}-${var.environment}-db-sg"
  description = "Postgres access from ECS tasks only"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.project}-${var.environment}-db-sg"
  }
}

# allows application tasks to connect to PostgreSQL
resource "aws_vpc_security_group_ingress_rule" "db_from_tasks" {
  security_group_id            = aws_security_group.db.id
  description                  = "Postgres from ECS tasks"
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
  referenced_security_group_id = var.task_security_group_id
}

resource "random_password" "db" {
  count                       = local.is_replica ? 0 : 1
    length           = 32
    special          = false # avoids URL-encoding trouble in DB_URL
  }

# creates the encrypted PostgreSQL database or cross-region read replica
resource "aws_db_instance" "this" {
  identifier             = "${var.project}-${var.environment}-db"
  # primary-only settings (null on a replica, which inherits them)
  engine                      = local.is_replica ? null : "postgres"
  engine_version              = local.is_replica ? null : "16"
  allocated_storage           = local.is_replica ? null : 20
  db_name                     = local.is_replica ? null : var.db_name
  username                    = local.is_replica ? null : var.db_username
  password                    = local.is_replica ? null : random_password.db[0].result
  backup_retention_period     = local.is_replica ? null : 1

  replicate_source_db = var.replicate_source_arn

  instance_class         = var.instance_class
  storage_encrypted      = true
  kms_key_id             = aws_kms_key.rds.arn
  db_subnet_group_name   = var.db_subnet_group_name
  vpc_security_group_ids = [aws_security_group.db.id]
  publicly_accessible    = false

  # demo settings
  skip_final_snapshot = true
  deletion_protection = false
  apply_immediately   = true

  tags = {
    Name = "${var.project}-${var.environment}-db"
  }
}