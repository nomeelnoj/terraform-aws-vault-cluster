resource "aws_s3_bucket" "default" {
  bucket        = var.bucket

  tags = merge(
    var.tags,
    {
      Name = var.bucket
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
resource "aws_s3_bucket_policy" "default" {
  bucket = aws_s3_bucket.default.bucket
  policy = var.s3_policy
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
      sse_algorithm     = var.sse
    }
  }
}
