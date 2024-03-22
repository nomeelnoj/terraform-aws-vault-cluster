data "aws_ami" "ubuntu" {
  count       = var.server["ami_id"] != null ? 0 : 1
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-${var.server["arch"]}-server*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

data "aws_ami" "custom" {
  count = vart.server["ami_id"] != null ? 1 : 0
  filter {
    name   = "image-id"
    values = [var.server["ami_id"]]
  }
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
  name                   = var.vault_config["vault_name"]
  description            = "Launch template for Vault ${var.vault_config["vault_name"]}"
  image_id               = var.server["ami_id"] != null ? var.server["ami_id"] : data.aws_ami.ubuntu[0].id
  instance_type          = var.server["instance_type"]
  key_name               = var.server["key_name"] != null ? var.server["key_name"] : try(aws_key_pair.default[0].key_name, null)
  update_default_version = true
  user_data              = data.cloudinit_config.user_data.rendered

  vpc_security_group_ids = [
    aws_security_group.server.id,
  ]

  block_device_mappings {
    device_name = var.server["root_device_name"] != null ? var.server["root_device_name"] : data.aws_ami.ubuntu[0].root_device_name

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
        Name = "${var.vault_config["vault_name"]}-server:${var.server["root_device_name"] != null ? var.server["root_device_name"] : data.aws_ami.ubuntu[0].root_device_name}"
      }
    )
  }

  tag_specifications {
    resource_type = "instance"
    tags = merge(
      local.tags,
      {
        Name = "${var.vault_config["vault_name"]}-server"
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

  lifecycle {
    precondition {
      condition     = var.server["create_key_name"] == "" || var.server["key_name"] == null
      error_message = "`var.server[\"create_key_name\"]` and `var.server[\"key_name\"]` are mutually exclusive. Use `var.server[\"create_key_name\"]` to name the key in `var.server[\"ssh_public_key\"]`, and use `var.server[\"key_name\"]` to use a key that already exists in AWS."
    }

    precondition {
      condition     = var.server["ami_id"] != null ? var.server["root_device_name"] != null : true
      error_message = "If you specify `var.server[\"ami_id\"]`, you must also specify `var.server[\"root_device_name\"]`."
    }
  }
}

resource "aws_key_pair" "default" {
  count      = var.server["ssh_public_key"] != null ? 1 : 0
  key_name   = var.server["create_key_name"]
  public_key = var.server["ssh_public_key"]
}
