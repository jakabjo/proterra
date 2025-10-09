provider "aws" { region = "us-west-2" }

variables {
  customer_gateway_ip         = "203.0.113.10"
  onprem_cidr                 = "192.168.0.0/16"
  hosted_zone_id              = "Z123456789ABCDEFG"
  listener_dns_name           = "prodaglistener.example.com"
  onprem_listener_ip          = "10.1.1.50"
  ad_domain_name              = "corp.example.com"
  ad_join_user                = "corp\svc-join"
  ad_join_password_ssm_param  = "/corp/joinsvc/password"
}

run "init" { command = ["init", "-upgrade"] }
run "plan" { command = ["plan", "-input=false"] }

assert {
  condition     = length(resource_changes.where(type == "aws_ec2_transit_gateway" && change.actions contains "create")) == 1
  error_message = "Transit Gateway not planned for creation"
}
assert {
  condition     = length(resource_changes.where(type == "aws_vpn_connection" && change.actions contains "create")) == 1
  error_message = "VPN to TGW not planned"
}
assert {
  condition     = length(resource_changes.where(type == "aws_lb" && change.actions contains "create")) == 1
  error_message = "NLB not planned"
}
assert {
  condition = alltrue([
    length(resource_changes.where(type == "aws_lb_target_group" && change.after.target_type == "ip")) == 1,
    length(resource_changes.where(type == "aws_lb_target_group" && tostring(change.after.health_check.port) == "59999")) == 1
  ])
  error_message = "Target group must use IP targets and health port 59999"
}
assert {
  condition     = length(resource_changes.where(type == "aws_cloudwatch_metric_alarm" && change.after.metric_name == "HealthyHostCount")) == 1
  error_message = "CloudWatch alarm missing"
}
assert {
  condition = alltrue([
    length(resource_changes.where(type == "aws_route53_record" && change.after.set_identifier == "primary"   && change.after.type == "CNAME")) == 1,
    length(resource_changes.where(type == "aws_route53_record" && change.after.set_identifier == "secondary" && change.after.type == "A")) == 1
  ])
  error_message = "DNS failover records missing or wrong types"
}
assert {
  condition     = length(resource_changes.where(type == "aws_instance" && change.actions contains "create")) == 2
  error_message = "Two EC2 instances not planned"
}
