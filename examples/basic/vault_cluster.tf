locals {
  name = "vault"
  env  = "dev"
}

module "vault_cluster" {
  providers = {
    aws.dns                   = aws.dns
    aws.s3_enterprise_license = aws.central-account
  }
  source = "git::git@github.com:nomeelnoj/terraform-aws-vault-cluster.git?ref=v0.0.3"

  subnet_ids = data.aws_subnets.default.ids
  vpc_id     = data.aws_vpc.default.id

  vault_name      = "${local.name}-${local.env}"
  vault_version   = "1.14.2-1"
  ttl             = "24h"
  ssh_public_key  = "ssh ed25519..."
  create_key_name = "${local.name}-${local.env}-${substr(sha256("${local.name}-${local.env}"), 0, 8)}"

  hosted_zone = "${local.env}.mydomain.com"
  hostname    = "${local.name}.${local.env}.mydomain.com"
  bucket      = "${local.name}-${local.env}-${substr(sha256("${local.name}-${local.env}"), 0, 8)}"

  load_balancer_ingress_cidrs = ["10.42.0.0/16"]
  ssh_ingress_cidrs           = ["10.42.42.0/24"]
  tags = {
    Environment     = local.env
    TerraformBucket = "mybucket"
    TerraformState  = "path/to/state/file/terraform.tfstate"
    Service         = "vault"
    Team            = "owning-team"
  }
}

