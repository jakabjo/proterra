# SQL AG Hybrid on AWS — Modular Terraform

This repository provides a **modular** Terraform implementation of a single-subnet, hybrid WSFC + SQL Server Always On design on AWS.

## Modules
- `modules/network` — VPC, private subnet, route table
- `modules/tgw_vpn` — Transit Gateway hub + Site-to-Site VPN + route to on-prem
- `modules/compute` — Windows EC2 nodes, IAM, Security Group, SSM health probe
- `modules/nlb` — Network Load Balancer with IP targets and custom health check
- `modules/monitoring` — CloudWatch alarm on Target Group healthy hosts
- `modules/dns` — Route 53 failover (PRIMARY CNAME → NLB with CW health; SECONDARY A → on-prem)

## Quick start
```bash
terraform init
terraform validate
terraform plan   -var='customer_gateway_ip=YOUR.CGW.IP'   -var='onprem_cidr=YOUR/ONPREM/CIDR'   -var='hosted_zone_id=Zxxxxxxxxxxxx'   -var='listener_dns_name=prodaglistener.example.com'   -var='onprem_listener_ip=10.1.1.50'   -var='ad_domain_name=corp.example.com'   -var='ad_join_user=corp\svc-join'   -var='ad_join_password_ssm_param=/corp/joinsvc/password'
terraform test
# terraform apply  (when ready)
```

## terraform test
`tests/plan.tftest.hcl` validates:
- TGW + VPN
- NLB with IP targets on health port 59999
- CloudWatch alarm on HealthyHostCount
- Route53 PRIMARY CNAME + SECONDARY A
- Two EC2 nodes

Run with:
```bash
terraform test
```

## Notes
- The health probe service is kept **up only on the AG primary** so the NLB forwards writes correctly.
- Ensure the `SqlServer` PowerShell module is available (bake into AMI or install in user_data).
