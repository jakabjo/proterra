resource "aws_cloudwatch_metric_alarm" "tg_healthy_zero" {
  alarm_name          = "${var.project}-tg-healthy-zero"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "HealthyHostCount"
  namespace           = "AWS/NetworkELB"
  period              = 30
  statistic           = "Average"
  threshold           = 1
  alarm_description   = "NLB target group has zero healthy hosts"
  dimensions = {
    TargetGroup = var.tg_arn_suffix
    LoadBalancer = var.lb_arn_suffix
  }
  treat_missing_data = "breaching"
}
