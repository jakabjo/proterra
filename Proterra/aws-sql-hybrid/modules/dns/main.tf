resource "aws_route53_health_check" "tg_cw_health" {
  type                          = "CLOUDWATCH_METRIC"
  cloudwatch_alarm_name         = var.cw_alarm_name
  cloudwatch_alarm_region       = var.region

  # Handle new or missing datapoints gracefully
  insufficient_data_health_status = "Unhealthy"
}

resource "aws_route53_record" "primary" {
  zone_id        = var.hosted_zone_id
  name           = var.listener_dns_name
  type           = "CNAME"
  ttl            = 10
  set_identifier = "primary"
  failover_routing_policy { type = "PRIMARY" }
  records         = [var.nlb_dns_name]
  health_check_id = aws_route53_health_check.tg_cw_health.id
}

resource "aws_route53_record" "secondary" {
  zone_id        = var.hosted_zone_id
  name           = var.listener_dns_name
  type           = "A"
  ttl            = 10
  set_identifier = "secondary"
  failover_routing_policy { type = "SECONDARY" }
  records = [var.onprem_listener_ip]
}
