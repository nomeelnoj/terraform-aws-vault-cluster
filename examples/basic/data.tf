data "aws_region" "current" {}

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
