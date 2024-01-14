locals {
  name = "vault"
  env  = "dev"
}

module "vault_cluster" {
  providers = {
    aws.dns                   = aws.dns
    aws.s3_enterprise_license = aws.central-account
  }
  source = "git::git@github.com:nomeelnoj/terraform-aws-vault-cluster.git?ref=1.0.0"

  subnet_ids = data.aws_subnets.default.ids
  vpc_id     = data.aws_vpc.default.id

  vault_config = {
    vault_name    = "${local.name}-${local.env}"
    vault_version = "1.15.4-1"
  }
  cert = {
    ttl = "24h"
  }


  dns = {
    hosted_zone = "${local.env}.mydomain.com"
    hostname    = "${local.name}.${local.env}.mydomain.com"
  }
  s3 = {
    bucket = "${local.name}-${local.env}-${substr(sha256("${local.name}-${local.env}"), 0, 8)}"
  }
  load_balancer = {
    ingress_cidrs           = ["10.42.0.0/16"]
    ingress_security_groups = ["sg-1234567abcde"]
  }
  tags = {
    Environment     = local.env
    TerraformBucket = "mybucket"
    TerraformState  = "path/to/state/file/terraform.tfstate"
    Service         = "vault"
    Team            = "owning-team"
  }
}

output "cert_data" {
  value     = module.vault_cluster.cert_data
  sensitive = true
}
