resource "aws_security_group" "alb" {
  name        = "alb-sg"
  vpc_id      = var.vpc_id
  description = "ALB"
  tags        = merge(var.tags, { Name = "alb-sg" })
}
resource "aws_security_group_rule" "alb_in_http" {
  type = "ingress" from_port = 80 to_port = 80 protocol = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
  security_group_id = aws_security_group.alb.id
}
resource "aws_security_group" "app" {
  name = "app-sg" vpc_id = var.vpc_id
  description = "App"
  tags = merge(var.tags, { Name = "app-sg" })
}
resource "aws_security_group_rule" "app_in_from_alb" {
  type = "ingress" from_port = 80 to_port = 80 protocol = "tcp"
  security_group_id = aws_security_group.app.id
  source_security_group_id = aws_security_group.alb.id
}
resource "aws_security_group" "db" {
  name = "db-sg" vpc_id = var.vpc_id
  description = "Postgres"
  tags = merge(var.tags, { Name = "db-sg" })
}
resource "aws_security_group_rule" "db_in_from_app" {
  type = "ingress" from_port = 5432 to_port = 5432 protocol = "tcp"
  security_group_id = aws_security_group.db.id
  source_security_group_id = aws_security_group.app.id
}
# Egress scoping (optional: default egress is allow-all; tighten where desired)
resource "aws_security_group_rule" "alb_eg_to_app" {
  type = "egress" from_port = 80 to_port = 80 protocol = "tcp"
  security_group_id = aws_security_group.alb.id
  source_security_group_id = aws_security_group.app.id
}
