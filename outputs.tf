output "aws_caller_identity" {
  description = "The caller identity object of the currently running Terraform user"
  value       = data.aws_caller_identity.current
}

output "s3" {
  description = "The entire s3 bucket object for vault backups"
  value       = aws_s3_bucket.default
}
output "security_group" {
  description = "All security group objects"
  value = {
    server        = aws_security_group.server
    load_balancer = aws_security_group.lb
  }
}

output "subnets" {
  description = "The subnet objects for the subnets used in this module"
  value       = data.aws_subnet.default
}
