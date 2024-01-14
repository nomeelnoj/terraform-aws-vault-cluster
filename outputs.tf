output "aws_caller_identity" {
  description = "The caller identity object of the currently running Terraform user"
  value       = data.aws_caller_identity.current
}

output "s3" {
  description = "The entire s3 bucket object for vault backups"
  value       = aws_s3_bucket.default
}

output "kms" {
  description = "All kms key objects created by the module"
  value = {
    auto_unseal = aws_kms_key.default["auto_unseal"]
    s3          = try(aws_kms_key.default["s3"], "")
  }
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

output "iam" {
  description = "The IAM role used for the vault nodes"
  value       = aws_iam_role.default
}

output "cert_data" {
  value = {
    "/opt/vault/tls/vault-key.pem"  = local.cert_key
    "/opt/vault/tls/vault-ca.pem"   = local.cert_chain
    "/opt/vault/tls/vault-cert.pem" = local.cert_pem
  }
  sensitive   = true
  description = "The values of the certificate, helpful for when mTLS certs need to rotate across nodes.  See docs at docs/rotating_vault_certificates.md."
}
