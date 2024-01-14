locals {
  # A policy that does not allow crossing encryption methods in the bucket
  # as it can lead to pain in debugging why some files are accessible and others
  # are not.
  policies_computed = merge(
    {
      deny_wrong_encryption = {
        sid     = "DenyEncryptionHeadersThatDoNotMatchBucketEncryption"
        effect  = "Deny"
        actions = ["s3:PutObject"]
        principals = [
          {
            type        = "AWS"
            identifiers = ["*"]
          }
        ]
        resources = [] # Defaults to bucket and bucket contents
        conditions = [
          {
            test     = "StringEquals"
            variable = "s3:x-amz-server-side-encryption"
            values   = [var.s3["sse"] == "aws:kms" ? "AES256" : "aws:kms"]
          }
        ]
      }
      default = {
        sid    = "AllowVaultRoleAccess"
        effect = "Allow"
        principals = [
          {
            type = "AWS"
            identifiers = [
              aws_iam_role.default.arn
            ]
          }
        ]
        actions = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:AbortMultipartUpload",
        ]
        resources = [] # Defaults to bucket and bucket contents
      }
    },
    var.s3["policy_statements"]
  )
}

resource "aws_s3_bucket" "default" {
  bucket        = var.s3["bucket"]
  force_destroy = var.s3["force_destroy"]

  tags = merge(
    var.tags,
    {
      Name = var.s3["bucket"]
    },
  )

  lifecycle {
    ignore_changes = [
      lifecycle_rule,
      replication_configuration,
      server_side_encryption_configuration,
      logging,
      cors_rule,
      grant,
      versioning,
      website
    ]
  }
}

data "aws_iam_policy_document" "default" {
  dynamic "statement" {
    for_each = local.policies_computed
    content {
      sid    = statement.value["sid"]
      effect = statement.value["effect"]

      dynamic "principals" {
        for_each = coalesce(lookup(statement.value, "principals", []), [])
        content {
          type        = principals.value["type"]
          identifiers = principals.value["identifiers"]
        }
      }

      dynamic "not_principals" {
        for_each = coalesce(lookup(statement.value, "not_principals", []), [])
        content {
          type        = not_principals.value["type"]
          identifiers = not_principals.value["identifiers"]
        }
      }

      actions     = lookup(statement.value, "actions", null)
      not_actions = lookup(statement.value, "not_actions", null)
      resources = length(coalesce(lookup(statement.value, "resources", []), [])) > 0 ? lookup(statement.value, "resources", []) : [
        # Preference is to use resource outputs here, but any time any attribute of the bucket changes,
        # terraform is not certain the ARN will be the same, so the plan shows a full re-calculation of the policy
        # By hard-coding the ARNs, we avoid this confusing output
        "arn:aws:s3:::${var.s3["bucket"]}",
        "arn:aws:s3:::${var.s3["bucket"]}/*"
      ]
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

resource "aws_s3_bucket_policy" "default" {
  bucket = aws_s3_bucket.default.bucket
  policy = data.aws_iam_policy_document.default.json
}

resource "aws_s3_bucket_public_access_block" "default" {
  bucket = aws_s3_bucket.default.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  depends_on = [
    aws_s3_bucket.default,
    aws_s3_bucket_policy.default,
  ]
}


resource "aws_s3_bucket_server_side_encryption_configuration" "default" {
  bucket = aws_s3_bucket.default.bucket

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.s3["sse"]
      kms_master_key_id = var.s3["sse"] == "AES256" ? null : aws_kms_key.default["s3"].arn
    }
  }
}

# This object is used to show differences in the plan for user_data since we b64 and gzip it
# It is stored in the S3 backups bucket so that terraform can show you the diff, making
# creating changes in user-data easy to identify in `terraform plan`
resource "aws_s3_object" "user_data" {
  bucket     = aws_s3_bucket.default.bucket
  key        = "cloudinit/user_data.sh"
  kms_key_id = var.s3["sse"] == "aws:kms" ? aws_kms_key.default["s3"].arn : null
  content = templatefile("${path.module}/templates/user_data.sh.tpl",
    {
      for k, v in local.user_data_values : k => k == "cert_key" ? "redacted" : v
    }
  )
}
