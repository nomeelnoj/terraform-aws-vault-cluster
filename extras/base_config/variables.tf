variable "snapshotter_role_arn" {
  description = "The ARN of the IAM role that is bound to the vault instances and will be used to take and upload snapshots to S3."
  type        = string
}
