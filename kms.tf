locals {
  default_kms_policy = {
    default = { # This policy allows us to use user/role policies for key access
      sid     = "Enale IAM User Permissions"
      effect  = "Allow"
      actions = ["kms:*"]
      principals = [
        {
          type        = "AWS"
          identifiers = [data.aws_caller_identity.current.account_id]
        }
      ]
      resources = ["*"]
    }
  }
  kms_admin_policy = try(var.kms["admin_arns"], null) != null ? {
    admin = {
      sid    = "EnableKeyAdministrationWithoutUse"
      effect = "Allow"
      principals = [
        {
          type        = "AWS"
          identifiers = var.kms["admin_arns"]
        }
      ]
      actions = [
        "kms:CancelKeyDeletion",
        "kms:CreateAlias",
        "kms:CreateCustomKeyStore",
        "kms:CreateGrant",
        "kms:CreateKey",
        "kms:DeleteAlias",
        "kms:DeleteCustomKeyStore",
        "kms:DeleteImportedKeyMaterial",
        "kms:DescribeCustomKeyStores",
        "kms:DescribeKey",
        "kms:DisableKey",
        "kms:DisableKeyRotation",
        "kms:EnableKey",
        "kms:EnableKeyRotation",
        "kms:GetKeyPolicy",
        "kms:GetKeyRotationStatus",
        "kms:GetParametersForImport",
        "kms:GetPublicKey",
        "kms:ListAliases",
        "kms:ListGrants",
        "kms:ListKeyPolicies",
        "kms:ListKeys",
        "kms:ListResourceTags",
        "kms:ListRetirableGrants",
        "kms:PutKeyPolicy",
        "kms:RevokeGrant",
        "kms:ScheduleKeyDeletion",
        "kms:TagResource",
        "kms:UntagResource",
        "kms:UpdateAlias",
        "kms:UpdateCustomKeyStore",
        "kms:UpdateKeyDescription",
        "kms:UpdatePrimaryRegion",
      ]
    }
  } : {}

  unseal_policy = {
    unseal = {
      sid    = "VaultNodeAutoUnsealAndS3Policy"
      effect = "Allow"
      principals = [
        {
          type        = "AWS"
          identifiers = [aws_iam_role.default.arn]
        }
      ]
      actions = [
        "kms:Decrypt",
        "kms:DescribeKey",
        "kms:Encrypt",
      ]
    }
  }

  kms_policy_statements = merge(
    local.unseal_policy,
    local.default_kms_policy,
    local.kms_admin_policy,
    try(var.kms["policy_statements"], {})
  )

  s3_kms_policy = {
    s3_backup_upload = {
      sid    = "AllowVaultToUploadBackups"
      effect = "Allow"
      principals = [
        {
          type        = "AWS"
          identifiers = [aws_iam_role.default.arn]
        }
      ]
      actions = [
        "kms:GenerateDataKey"
      ]
    }
  }

  kms_cloudwatch_policy = {
    cloudwatch = {
      sid    = "AllowCloudwatchLogsAccess"
      effect = "Allow"
      principals = [
        {
          type = "Service"
          identifiers = [
            "logs.${var.aws_region}.amazonaws.com"
          ]
        }
      ]
      actions = [
        "kms:Decrypt",
        "kms:DescribeCustomKeyStores",
        "kms:DescribeKey",
        "kms:Encrypt",
        "kms:GenerateDataKey",
        "kms:GenerateDataKeyPair",
        "kms:GenerateDataKeyPairWithoutPlaintext",
        "kms:GenerateDataKeyWithoutPlaintext",
        "kms:ReEncryptFrom",
        "kms:ReEncryptTo",
      ]
      resources = ["*"]
      conditions = [
        {
          test     = "ArnEquals"
          variable = "kms:EncryptionContext:aws:logs:arn"
          values = [
            # Cycle issue, need to hard code
            "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/hashicorp/vault/${var.vault_config["vault_name"]}"
          ]
        }
      ]
    }
  }

  kms_keys = merge(
    {
      auto_unseal = {
        name              = "/hashicorp/vault/${var.vault_config["vault_name"]}-auto-unseal"
        policy_statements = local.kms_policy_statements
      }
      cloudwatch = {
        name = "/cloudwatch/hashicorp/vault/${var.vault_config["vault_name"]}"
        policy_statements = merge(
          local.default_kms_policy,
          local.kms_cloudwatch_policy,
          local.kms_admin_policy
        )
      }
    },
    var.s3["sse"] == "AES256" ? {} : {
      s3 = {
        name = "/aws/s3/${var.s3["bucket"]}"
        policy_statements = merge(
          local.default_kms_policy,
          local.kms_admin_policy,
          local.s3_kms_policy,
          lookup(var.s3, "kms_policy_statements", {})
        )
      }
    }
  )
}


resource "aws_kms_key" "default" {
  for_each    = local.kms_keys
  description = each.value["name"]
  tags = merge(
    var.tags,
    {
      Name = each.value["name"]
    }
  )
}

resource "aws_kms_key_policy" "default" {
  for_each                           = local.kms_keys
  key_id                             = aws_kms_key.default[each.key].id
  policy                             = data.aws_iam_policy_document.kms[each.key].json
  bypass_policy_lockout_safety_check = false
}

resource "aws_kms_alias" "default" {
  for_each      = local.kms_keys
  name          = "alias/${each.value["name"]}"
  target_key_id = aws_kms_key.default[each.key].key_id
}

data "aws_iam_policy_document" "kms" {
  for_each = local.kms_keys
  dynamic "statement" {
    for_each = each.value["policy_statements"]
    content {
      sid    = statement.value["sid"]
      effect = statement.value["effect"]

      dynamic "principals" {
        for_each = statement.value["principals"]
        content {
          type        = principals.value["type"]
          identifiers = principals.value["identifiers"]
        }
      }
      actions   = statement.value["actions"]
      resources = ["*"]
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
