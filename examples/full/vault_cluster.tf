locals {
  name   = "vault"
  env    = "dev"
  region = data.aws_region.current.name
}

module "vault_cluster" {
  providers = {
    aws.dns                   = aws.dns
    aws.s3_enterprise_license = aws.central-account
  }
  source     = "git::git@github.com:nomeelnoj/terraform-aws-vault-cluster.git?ref=v0.0.3"
  subnet_ids = data.aws_subnets.default.ids
  vpc_id     = data.aws_vpc.default.id

  tags = {
    Environment     = local.env
    TerraformBucket = "mybucket"
    TerraformState  = "path/to/state/file/terraform.tfstate"
    Service         = "vault"
    Team            = "owning-team"
  }

  vault_name                = "${local.name}-${local.env}"
  vault_version             = "1.14.2+ent-1" # Setting this to +ent will deploy the enterprise binary. S3 bucket for license required (below)
  enterprise_license_bucket = "vault-enterprise-license-bucket"
  enterprise_license_s3_key = "vault.hclic"

  audit_log_path    = "/opt/vault/vault-audit.log"
  operator_log_path = "/var/log/vault-operator.log"

  disable_performance_standby = true
  ui                          = true
  disable_mlock               = true
  disable_sealwrap            = true
  auto_join_tag_key           = "vault-cluster-join"
  auto_join_tag_value         = "server"

  use_route53  = true
  hosted_zone  = "${local.env}.mydomain.com"
  hostname     = "${local.name}.${local.env}.mydomain.com"
  private_zone = true

  generate_local_cert           = true # required for first time setup
  ttl                           = "8760h"
  alt_names                     = ["${local.name}-cluster.${local.env}.mydomain.com"]
  vault_pki_secret_backend_role = "pki"

  ami_id            = data.aws_ami.ubuntu.id
  aws_region        = data.aws_region.current.name
  arch              = "arm64"
  node_count        = 3
  ssh_public_key    = "ssh-ed25519..."
  create_key_name   = local.name
  instance_type     = "m7g.medium"
  ssh_ingress_cidrs = ["10.42.42.0/24"]

  kms_admin_arns = flatten([
    [for arn in data.aws_iam_roles.sso_admin.arns : arn]
  ])
  kms_policy_statements = {
    unseal = {
      sid    = "AllowSomeTeamAccessToUnsealKey"
      effect = "Allow"
      principals = [
        {
          type        = "AWS"
          identifiers = [for arn in data.aws_iam_roles.sso_devops.arns : arn]
        }
      ]
      actions = [
        "kms:Decrypt",
        "kms:Encrypt",
        "kms:GenerateDataKey",
        "kms:ReEncrypt*",
        "kms:DescribeKey",
      ]
    }
  }

  health_check_path           = "/v1/sys/health?activecode=200&standbycode=200&sealedcode=200&uninitcode=200"
  health_check_matcher        = "200,429,472"
  load_balancer_ingress_cidrs = ["10.42.0.0/16"]

  log_retention = 14
  bucket        = "vault-${local.env}-backups-${substr(sha256("vault-${local.env}-backups"), 0, 8)}"
  force_destroy = true
  sse           = "aws:kms"

  s3_policy_statements = {
    block_cross_account = {
      sid     = "DenyAccessAcrossAccounts"
      effect  = "Deny"
      actions = ["s3:GetObject", "s3:ListBucket"]
      principals = [
        {
          type        = "AWS"
          identifiers = ["*"]
        }
      ]
      conditions = [
        {
          test     = "StringNotEquals"
          variable = "aws:PrincipalAccount"
          values   = [module.vault_cluster.aws_caller_identity.account_id]
        }
      ]
    }
  }

  max_session_duration = 7200
  iam_assume_role_policies = {
    admins = {
      sid    = "AllowVaultAdminsToAssumeNodeRole"
      effect = "Allow"
      principals = [
        {
          type        = "AWS"
          identifiers = [for arn in data.aws_iam_roles.sso_admin.arns : arn]
        }
      ]
      actions = ["sts:AssumeRole"]
      conditions = [
        {
          test     = "StringEquals"
          variable = "aws:PrincipalTag/Role"
          values   = ["vault-admin"]
        }
      ]
    }
  }

  iam_policy_statements = {
    ecr = {
      sid    = "AllowVaultIamToPullECR"
      effect = "Allow"
      actions = [
        "ecr:BatchCheckLayerAvailability",
        "ecr:BatchGetImage",
        "ecr:GetAuthorizationToken",
        "ecr:GetDownloadUrlForLayer",
        "ecr:GetRepositoryPolicy",
        "ecr:DescribeImages",
        "ecr:DescribeImageScanFindings",
        "ecr:DescribeRepositories",
        "ecr:GetLifecyclePolicy",
        "ecr:GetLifecyclePolicyPreview",
        "ecr:ListImages",
        "ecr:ListTagsForResource",
      ]
      resources = [
        "arn:aws:ecr:${local.region}:${module.vault_cluster.aws_caller_identity.account_id}:*"
      ]
    }
  }
}

