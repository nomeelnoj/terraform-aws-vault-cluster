locals {
  assume_role_policies = merge(
    {
      assume = {
        sid     = "AllowEC2AssumptionForVaultNodes"
        effect  = "Allow"
        actions = ["sts:AssumeRole"]
        principals = [
          {
            type        = "Service"
            identifiers = ["ec2.amazonaws.com"]
          }
        ]
      }
    },
    { for statement in var.iam_assume_role_policies : statement["sid"] => statement }
  )

  iam_policy_statements = merge(
    {
      cluster_auto_join = {
        sid    = "AllowVaultNodesToAutoJoinCluster"
        effect = "Allow"
        actions = [
          "ec2:DescribeInstances"
        ]
        resources = ["*"]
      },
      auto_unseal = {
        sid    = "AllowVaultNodesToAutoUnseal"
        effect = "Allow"
        actions = [
          "kms:DescribeKey",
          "kms:Encrypt",
          "kms:Decrypt",
        ]
        resources = flatten([
          aws_kms_key.default["auto_unseal"].arn,
        ])
      }
      session_manager = {
        sid    = "AllowVaultAccessToSessionManager"
        effect = "Allow"
        actions = [
          "ssm:UpdateInstanceInformation",
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel"
        ]
        resources = ["*"]
      }
      s3_backups = {
        sid    = "AllowAccessToS3BackupBucket"
        effect = "Allow"
        actions = [
          "s3:PutObject",
        ]
        resources = [
          aws_s3_bucket.default.arn
        ]
      }
      iam = {
        sid    = "AllowIdentifyingIAMPrincipalsForAWSPolicies"
        effect = "Allow"
        actions = [
          "iam:GetRole",
          "iam:GetUser",
        ]
        resources = ["*"]
      }
    },
    var.enterprise_license_bucket != null ? {
      s3_enterprise = {
        sid    = "AllowAccessToReadVaultLicenseFromS3"
        effect = "Allow"
        actions = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        resources = [
          data.aws_s3_bucket.enterprise_license[0].arn,
          "${data.aws_s3_bucket.enterprise_license[0].arn}/*"
        ]
      }
    } : null,
    var.iam_policy_statements
  )

  iam_policy_attachments = flatten([
    data.aws_iam_policy.cloudwatch.arn,
    data.aws_iam_policy.ssm.arn,
    var.iam_policy_attachments
  ])
}

data "aws_iam_policy_document" "assume" {
  dynamic "statement" {
    for_each = local.assume_role_policies
    content {
      sid     = lookup(statement.value, "sid", "")
      effect  = lookup(statement.value, "effect", "Allow")
      actions = lookup(statement.value, "actions", ["sts:AssumeRole"])
      dynamic "principals" {
        for_each = statement.value["principals"]
        content {
          type        = principals.value["type"]
          identifiers = principals.value["identifiers"]
        }
      }
      dynamic "condition" {
        for_each = length(coalesce(lookup(statement.value, "conditions", []), [])) == 0 ? [] : lookup(statement.value, "conditions")
        content {
          test     = lookup(condition.value, "test", null)
          variable = lookup(condition.value, "variable", null)
          values   = lookup(condition.value, "values", null)
        }
      }
    }
  }
}

resource "aws_iam_role" "default" {
  name                 = var.vault_name
  description          = "For Vault ${var.vault_name} - Managed by Terraform"
  max_session_duration = var.max_session_duration
  assume_role_policy   = data.aws_iam_policy_document.assume.json

  tags = merge(
    local.tags,
    {
      Name = var.vault_name
    }
  )
}
data "aws_iam_policy" "cloudwatch" {
  name = "CloudWatchAgentServerPolicy"
}

data "aws_iam_policy" "ssm" {
  name = "AmazonSSMManagedInstanceCore"
}

data "aws_iam_policy_document" "iam" {
  dynamic "statement" {
    for_each = local.iam_policy_statements
    content {
      sid           = lookup(statement.value, "sid", "")
      effect        = lookup(statement.value, "effect")
      actions       = lookup(statement.value, "actions", [])
      not_actions   = lookup(statement.value, "not_actions", null)
      resources     = lookup(statement.value, "resources", [])
      not_resources = lookup(statement.value, "not_resources", null)
      dynamic "condition" {
        for_each = length(coalesce(lookup(statement.value, "conditions", []), [])) == 0 ? [] : lookup(statement.value, "conditions")
        content {
          test     = lookup(condition.value, "test", null)
          variable = lookup(condition.value, "variable", null)
          values   = lookup(condition.value, "values", null)
        }
      }
    }
  }
}

resource "aws_iam_role_policy" "default" {
  name   = "terraform-managed-policy"
  role   = aws_iam_role.default.id
  policy = data.aws_iam_policy_document.iam.json
}

resource "aws_iam_role_policy_attachment" "default" {
  for_each   = toset(local.iam_policy_attachments)
  role       = aws_iam_role.default.name
  policy_arn = each.value
}

resource "aws_iam_instance_profile" "default" {
  name = aws_iam_role.default.name
  role = aws_iam_role.default.name
  tags = merge(
    local.tags,
    {
      Name = aws_iam_role.default.name
    }
  )
}
