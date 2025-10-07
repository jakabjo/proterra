output "rds_endpoint"            { value = aws_db_instance.postgres.address }
output "db_password_secret_arn"  { value = aws_secretsmanager_secret.db_password.arn }
output "db_creds_secret_arn"     { value = aws_secretsmanager_secret.db_creds.arn }
output "db_endpoint_param_arn"   { value = aws_ssm_parameter.endpoint.arn }
output "db_name_param_arn"       { value = aws_ssm_parameter.dbname.arn }
output "db_user_param_arn"       { value = aws_ssm_parameter.dbuser.arn }
