resource "aws_cloudwatch_log_group" "default" {
  name              = "/hashicorp/vault/${var.vault_name}"
  retention_in_days = var.log_retention
  kms_key_id        = aws_kms_key.default["cloudwatch"].arn

  tags = merge(
    local.tags,
    {
      Name = "/hashicorp/vault/${var.vault_name}"
    }
  )
  depends_on = [aws_kms_key_policy.default]
}
