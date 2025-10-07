output "vpc_id"         { value = module.network.vpc_id }
output "alb_dns_name"   { value = module.compute.alb_dns_name }
output "asg_name"       { value = module.compute.asg_name }
output "rds_endpoint"   { value = module.data.rds_endpoint }
output "s3_bucket"      { value = module.storage.app_bucket }
output "alb_logs_bucket"{ value = module.storage.alb_logs_bucket }
output "db_secret_arn"  { value = module.data.db_creds_secret_arn }
