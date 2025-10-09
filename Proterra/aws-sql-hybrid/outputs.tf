output "vpc_id"          { value = module.network.vpc_id }
output "subnet_id"       { value = module.network.subnet_id }
output "tgw_id"          { value = module.tgw_vpn.tgw_id }
output "vpn_id"          { value = module.tgw_vpn.vpn_id }
output "nlb_dns_name"    { value = module.nlb.nlb_dns_name }
output "listener_record" { value = module.dns.listener_fqdn }
output "sql_instance_ips" { value = module.compute.instance_private_ips }
