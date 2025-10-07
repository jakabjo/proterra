# Global tags & 2 AZs
data "aws_availability_zones" "available" { state = "available" }
locals {
  azs      = slice(data.aws_availability_zones.available.names, 0, 2)
  tags_all = merge(var.tags, { Project = var.project, Env = var.env, Owner = var.owner, ManagedBy = "terraform" })
}

module "network" {
  source   = "./modules/network"
  name     = var.name
  vpc_cidr = var.vpc_cidr
  azs      = local.azs
  tags     = local.tags_all
}

module "security" {
  source = "./modules/security"
  vpc_id = module.network.vpc_id
  tags   = local.tags_all
}

module "storage" {
  source = "./modules/storage"
  name   = var.name
  env    = var.env
  tags   = local.tags_all
}

module "iam" {
  source = "./modules/iam"
  name   = var.name
  tags   = local.tags_all

  # Narrowed later once data module outputs ARNs; OK to start empty
  secret_arns    = []
  parameter_arns = []
}

module "compute" {
  source             = "./modules/compute"
  name               = var.name
  instance_type      = var.instance_type
  asg_min            = var.asg_min
  asg_max            = var.asg_max
  asg_desired        = var.asg_desired
  public_subnet_ids  = module.network.public_subnet_ids
  private_subnet_ids = module.network.private_subnet_ids
  vpc_id             = module.network.vpc_id
  alb_sg_id          = module.security.alb_sg_id
  app_sg_id          = module.security.app_sg_id
  alb_logs_bucket    = module.storage.alb_logs_bucket
  instance_profile   = module.iam.instance_profile_name
  tags               = local.tags_all
}


module "data" {
  source             = "./modules/data"
  name               = var.name
  vpc_id             = module.network.vpc_id
  private_subnet_ids = module.network.private_subnet_ids
  db_sg_id           = module.security.db_sg_id
  db_instance_class  = var.db_instance_class
  db_storage_gb      = var.db_storage_gb
  db_multi_az        = var.db_multi_az
  db_engine_version  = var.db_engine_version
  tags               = local.tags_all
}

# Now that secrets/params exist, give EC2 least-privilege read access
module "iam_narrow" {
  source = "./modules/iam"
  name   = "${var.name}-narrow"
  tags   = local.tags_all

  secret_arns    = [module.data.db_password_secret_arn, module.data.db_creds_secret_arn]
  parameter_arns = [module.data.db_endpoint_param_arn, module.data.db_name_param_arn, module.data.db_user_param_arn]

  # Reuse same role/profile so policy attachments land on EC2 role
  reuse_role_name          = module.iam.role_name
  reuse_instance_profile   = module.iam.instance_profile_name
}
