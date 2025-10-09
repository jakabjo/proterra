output "instance_private_ips" { value = [for i in aws_instance.sql_nodes : i.private_ip] }
output "security_group_id"     { value = aws_security_group.sql_sg.id }
output "instance_ids"          { value = [for i in aws_instance.sql_nodes : i.id] }
