variable "project" { type = string }
variable "vpc_id"   { type = string }
variable "subnet_id"{ type = string }
variable "sql_port" { type = number }
variable "health_port" { type = number }
variable "target_ips" { type = list(string) }
