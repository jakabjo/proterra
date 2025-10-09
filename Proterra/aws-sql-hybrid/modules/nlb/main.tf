resource "aws_lb" "nlb" {
  name               = "${var.project}-nlb"
  load_balancer_type = "network"
  subnets            = [var.subnet_id]
  enable_cross_zone_load_balancing = false
  tags = { Name = "${var.project}-nlb" }
}

resource "aws_lb_target_group" "sql_tg" {
  name        = "${var.project}-tg-sql"
  port        = var.sql_port
  protocol    = "TCP"
  target_type = "ip"
  vpc_id      = var.vpc_id

  health_check {
    protocol            = "TCP"
    port                = var.health_port
    interval            = 10
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }

  tags = { Name = "${var.project}-tg-sql" }
}

resource "aws_lb_target_group_attachment" "ip_targets" {
  for_each         = toset(var.target_ips)
  target_group_arn = aws_lb_target_group.sql_tg.arn
  target_id        = each.value
  port             = var.sql_port
}

resource "aws_lb_listener" "sql_listener" {
  load_balancer_arn = aws_lb.nlb.arn
  port              = var.sql_port
  protocol          = "TCP"
  default_action { type = "forward"; target_group_arn = aws_lb_target_group.sql_tg.arn }
}
