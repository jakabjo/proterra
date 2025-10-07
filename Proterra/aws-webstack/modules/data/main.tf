resource "aws_db_subnet_group" "db" {
  name       = "${var.name}-db-subnets"
  subnet_ids = var.private_subnet_ids
  tags       = var.tags
}

resource "random_password" "db" { length = 16 special = false }

resource "aws_db_instance" "postgres" {
  identifier              = "${var.name}-pg"
  engine                  = "postgres"
  engine_version          = var.db_engine_version
  instance_class          = var.db_instance_class
  allocated_storage       = var.db_storage_gb
  db_name                 = "appdb"
  username                = "appuser"
  password                = random_password.db.result
  db_subnet_group_name    = aws_db_subnet_group.db.name
  vpc_security_group_ids  = [var.db_sg_id]
  multi_az                = var.db_multi_az
  publicly_accessible     = false
  storage_encrypted       = true
  skip_final_snapshot     = true
  deletion_protection     = false
  backup_retention_period = 1
  apply_immediately       = true
  tags                    = var.tags
}

# Secrets Manager (password + JSON creds)
resource "aws_secretsmanager_secret" "db_password" {
  name = "${var.name}/db/password"
  tags = var.tags
}
resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = random_password.db.result
}
resource "aws_secretsmanager_secret" "db_creds" {
  name = "${var.name}/db/creds"
  tags = var.tags
}
resource "aws_secretsmanager_secret_version" "db_creds" {
  secret_id = aws_secretsmanager_secret.db_creds.id
  secret_string = jsonencode({
    username = "appuser",
    password = random_password.db.result
  })
}

# Parameter Store (endpoint/name/user)
resource "aws_ssm_parameter" "endpoint" {
  name  = "/${var.name}/db/endpoint"
  type  = "String"
  value = aws_db_instance.postgres.address
  tags  = var.tags
}
resource "aws_ssm_parameter" "dbname" {
  name  = "/${var.name}/db/name"
  type  = "String"
  value = "appdb"
  tags  = var.tags
}
resource "aws_ssm_parameter" "dbuser" {
  name  = "/${var.name}/db/username"
  type  = "String"
  value = "appuser"
  tags  = var.tags
}
