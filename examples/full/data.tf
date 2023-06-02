data "aws_region" "current" {}

data "aws_ami" "ubuntu" {
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-arm64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["099720109477"] # Canonical
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
  filter {
    name   = "tag:SubnetType"
    values = ["private"]
  }
}

data "aws_vpc" "default" {
  filter {
    name   = "tag:Name"
    values = [local.env]
  }
}

data "aws_iam_roles" "sso_admin" {
  path_prefix = "/aws-reserved/sso.amazonaws.com/"
  name_regex  = "^AWSReservedSSO_Administrator_.*"
}

data "aws_iam_roles" "sso_support" {
  path_prefix = "/aws-reserved/sso.amazonaws.com/"
  name_regex  = "^AWSReservedSSO_Support_.*"
}


data "aws_iam_roles" "sso_devops" {
  path_prefix = "/aws-reserved/sso.amazonaws.com/"
  name_regex  = "^AWSReservedSSO_DevopsAdmins_.*"
}
