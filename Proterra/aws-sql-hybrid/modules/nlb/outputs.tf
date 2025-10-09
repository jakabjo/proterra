output "nlb_dns_name" { value = aws_lb.nlb.dns_name }
output "tg_arn_suffix" { value = aws_lb_target_group.sql_tg.arn_suffix }
output "lb_arn_suffix" { value = aws_lb.nlb.arn_suffix }
