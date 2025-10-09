module "network" {
  source               = "./modules/network"
  project              = var.project
  vpc_cidr             = var.vpc_cidr
  private_subnet_cidr  = var.private_subnet_cidr
}

module "tgw_vpn" {
  source          = "./modules/tgw_vpn"
  project         = var.project
  vpc_id          = module.network.vpc_id
  subnet_id       = module.network.subnet_id
  route_table_id  = module.network.route_table_id
  onprem_cidr     = var.onprem_cidr
  customer_gateway_ip = var.customer_gateway_ip
}

module "compute" {
  source                 = "./modules/compute"
  project                = var.project
  vpc_id                 = module.network.vpc_id
  vpc_cidr               = var.vpc_cidr
  subnet_id              = module.network.subnet_id
  instance_type          = var.instance_type
  key_name               = var.key_name
  sql_port               = var.sql_port
  health_port            = var.health_port
  ad_domain_name         = var.ad_domain_name
  ad_join_user           = var.ad_join_user
  ad_join_password_ssm_param = var.ad_join_password_ssm_param
  ad_target_ou           = var.ad_target_ou
  onprem_cidr            = var.onprem_cidr
}

module "nlb" {
  source        = "./modules/nlb"
  project       = var.project
  vpc_id        = module.network.vpc_id
  subnet_id     = module.network.subnet_id
  sql_port      = var.sql_port
  health_port   = var.health_port
  target_ips    = module.compute.instance_private_ips
}

module "monitoring" {
  source       = "./modules/monitoring"
  project      = var.project
  tg_arn_suffix = module.nlb.tg_arn_suffix
  lb_arn_suffix = module.nlb.lb_arn_suffix
}

module "dns" {
  source               = "./modules/dns"
  project              = var.project
  region               = var.region
  hosted_zone_id       = var.hosted_zone_id
  listener_dns_name    = var.listener_dns_name
  onprem_listener_ip   = var.onprem_listener_ip
  nlb_dns_name         = module.nlb.nlb_dns_name
  cw_alarm_name        = module.monitoring.alarm_name
}
