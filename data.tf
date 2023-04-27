data "aws_caller_identity" "current" {}

data "aws_s3_bucket" "enterprise_license" {
  count    = var.enterprise_license_bucket != null ? 1 : 0
  provider = aws.s3_enterprise_license
  bucket   = var.enterprise_license_bucket
}

# Used in the vault config so that source IPs show up in the audit log
data "aws_subnet" "lb_header_passthrough" {
  for_each = toset(var.subnet_ids)
  id       = each.value
}
