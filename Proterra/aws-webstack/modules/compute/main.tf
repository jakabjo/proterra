# AMI (Amazon Linux 2, x86_64)
data "aws_ami" "al2" {
  most_recent = true
  owners      = ["amazon"]
  filter { name = "name" values = ["amzn2-ami-kernel-5.*-x86_64-gp2"] }
}

# Launch template (private only; SSM via instance profile; no SSH)
resource "aws_launch_template" "lt" {
  name_prefix   = "${var.name}-lt-"
  image_id      = data.aws_ami.al2.id
  instance_type = var.instance_type

  iam_instance_profile { name = var.instance_profile }

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [var.app_sg_id]
  }

  user_data = filebase64("${path.module}/user_data.sh")

  tag_specifications {
    resource_type = "instance"
    tags = merge(var.tags, { Name = "${var.name}-app" })
  }
  tags = var.tags
}

# ALB + TG + Listener (access logs enabled)
resource "aws_lb" "alb" {
  name               = "${var.name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_sg_id]
  subnets            = var.public_subnet_ids
  access_logs { bucket = var.alb_logs_bucket, prefix = var.name, enabled = true }
  tags = var.tags
}
resource "aws_lb_target_group" "tg" {
  name     = "${var.name}-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id
  health_check { path="/"; matcher="200-399"; interval=15; timeout=5; healthy_threshold=2; unhealthy_threshold=2 }
  tags = var.tags
}
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.alb.arn
  port = 80
  protocol = "HTTP"
  default_action { type = "forward" target_group_arn = aws_lb_target_group.tg.arn }
}

# ASG across private subnets, target group attached
resource "aws_autoscaling_group" "asg" {
  name                      = "${var.name}-asg"
  vpc_zone_identifier       = var.private_subnet_ids
  desired_capacity          = var.asg_desired
  min_size                  = var.asg_min
  max_size                  = var.asg_max
  health_check_type         = "EC2"
  health_check_grace_period = 90
  target_group_arns         = [aws_lb_target_group.tg.arn]

  launch_template { id = aws_launch_template.lt.id, version = "$Latest" }

  tags = concat(
    [ { key="Name", value="${var.name}-app", propagate_at_launch=true } ],
    [ for k,v in var.tags : { key=k, value=v, propagate_at_launch=true } ]
  )
}

# Target tracking scaling (CPU + Request count)
resource "aws_autoscaling_policy" "cpu_tgt" {
  name = "${var.name}-cpu-tt"
  autoscaling_group_name = aws_autoscaling_group.asg.name
  policy_type = "TargetTrackingScaling"
  target_tracking_configuration {
    predefined_metric_specification { predefined_metric_type = "ASGAverageCPUUtilization" }
    target_value = 50
  }
}
resource "aws_autoscaling_policy" "req_tgt" {
  name = "${var.name}-req-tt"
  autoscaling_group_name = aws_autoscaling_group.asg.name
  policy_type = "TargetTrackingScaling"
  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ALBRequestCountPerTarget"
      resource_label         = "${aws_lb.alb.arn_suffix}/${aws_lb_target_group.tg.arn_suffix}"
    }
    target_value = 100
  }
}
