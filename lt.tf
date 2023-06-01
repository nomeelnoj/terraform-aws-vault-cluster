data "aws_ami" "ubuntu" {
  count       = var.ami_id != null ? 0 : 1
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-${var.arch}-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

data "cloudinit_config" "user_data" {
  gzip          = true
  base64_encode = true

  part {
    content_type = "text/x-shellscript"
    filename     = "user_data.sh"
    content      = templatefile("${path.module}/templates/user_data.sh.tpl", local.user_data_values)
  }
}
resource "aws_launch_template" "default" {
  name                   = var.vault_name
  description            = "Launch template for Vault ${var.vault_name}"
  image_id               = var.ami_id != null ? var.ami_id : data.aws_ami.ubuntu[0].id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.default.key_name
  update_default_version = true
  user_data              = data.cloudinit_config.user_data.rendered
  vpc_security_group_ids = [
    aws_security_group.server.id,
  ]

  block_device_mappings {
    device_name = "/dev/sda1"

    ebs {
      volume_type           = "gp3"
      volume_size           = 100
      throughput            = 150
      iops                  = 3000
      delete_on_termination = true
    }
  }

  tag_specifications {
    resource_type = "volume"
    tags = merge(
      local.tags,
      {
        Name = "${var.vault_name}-server:/dev/sda1"
      }
    )
  }

  tag_specifications {
    resource_type = "instance"
    tags = merge(
      local.tags,
      {
        Name = "${var.vault_name}-server"
      }
    )
  }
  iam_instance_profile {
    arn = aws_iam_instance_profile.default.arn
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }
}


resource "aws_key_pair" "default" {
  key_name   = var.create_key_name
  public_key = var.ssh_public_key
  tags = merge(
    local.tags,
    {
      Name = var.create_key_name
    }
  )
}
