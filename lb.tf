data "aws_subnet" "default" {
  for_each = toset(var.subnet_ids)
  id       = each.value
}

resource "aws_lb" "default" {
  name               = var.vault_config["vault_name"]
  internal           = true
  load_balancer_type = "application"
  subnets            = var.subnet_ids
  security_groups = flatten([
    aws_security_group.lb.id,
    var.load_balancer["additional_lb_security_groups"]
  ])
  drop_invalid_header_fields = true

  tags = merge(
    local.tags,
    {
      Name = var.vault_config["vault_name"]
    },
  )
}

resource "aws_lb_target_group" "default" {
  name                 = var.vault_config["vault_name"]
  target_type          = "instance"
  port                 = 8200
  protocol             = "HTTPS"
  vpc_id               = var.vpc_id
  deregistration_delay = 0

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 5
    protocol            = "HTTPS"
    port                = "traffic-port"
    path                = var.load_balancer["health_check_path"]
    interval            = 30
    matcher             = var.load_balancer["health_check_matcher"]
  }

  tags = local.tags
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.default.id
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.default.id
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"
  certificate_arn   = aws_acm_certificate.default.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.default.arn
  }
}
