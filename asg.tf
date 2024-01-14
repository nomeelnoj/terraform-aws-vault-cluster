resource "aws_autoscaling_group" "default" {
  name                = var.vault_config["vault_name"]
  min_size            = var.server["node_count"]
  max_size            = var.server["node_count"]
  desired_capacity    = var.server["node_count"]
  vpc_zone_identifier = var.subnet_ids
  target_group_arns   = [aws_lb_target_group.default.arn]

  launch_template {
    id      = aws_launch_template.default.id
    version = aws_launch_template.default.default_version
  }

  health_check_grace_period = 180

  health_check_type = "ELB"

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 100 # Limit to replacing 1 instance at a time
      instance_warmup        = 300 # Wait 5 min for instance to come up before cycling next instance
    }
  }

  instance_maintenance_policy {
    min_healthy_percentage = 100
    max_healthy_percentage = 150
  }

  dynamic "tag" {
    for_each = merge(
      local.tags,
      {
        Name = "${var.vault_config["vault_name"]}-server"
      },
    )
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }
}
