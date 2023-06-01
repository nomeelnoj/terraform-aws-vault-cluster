variable "aws_region" {
  description = "The region to which you are deploying"
  type        = string
  default     = "us-east-1"
}

variable "use_route53" {
  description = "Whether to use route53. If not selected, hostname will not be managed."
  type        = bool
  default     = true
}

variable "hosted_zone" {
  description = "The name of the hosted zone to use"
  type        = string
  default     = null
}

variable "hostname" {
  description = "The hostname for the vault cluster"
  type        = string
}

variable "private_zone" {
  description = "Whether the route53 zone is private or not"
  type        = bool
  default     = true
}

variable "generate_local_cert" {
  description = "Whether to generate a local cert or use vault. Good for first time setups before you have a vault to bootstrap"
  type        = bool
  default     = false
}

variable "ttl" {
  description = "The TTL of the cert"
  type        = string
  default     = "8760h"
}

variable "alt_names" {
  description = "Alt names for the cert"
  type        = list(string)
  default     = null
}

variable "vault_pki_secret_backend_role" {
  description = "The role to use in vault when generating the cert"
  type        = string
  default     = "pki"
}

variable "ami_id" {
  description = "The ami id to use if you want to override the default most recent ubuntu image"
  type        = string
  default     = null
}

variable "arch" {
  description = "The architecture to use--arm64 or amd64"
  type        = string
  default     = "arm64"
  validation {
    condition     = contains(["arm64", "amd64"], var.arch)
    error_message = "The only supported architectures at this time are 'arm64' and 'amd64'.  Make sure your instance type matches the architecture you have set."
  }
}

variable "instance_type" {
  description = "The instance type to use for cluster instances"
  type        = string
  default     = "t4g.medium"
}

variable "node_count" {
  description = "The number of nodes in the cluster.  Must be an odd number greater than or equal to 3"
  type        = number
  default     = 3

  validation {
    condition     = var.node_count % 2 == 1 && var.node_count >= 3
    error_message = "Node count must be an odd number greater than or equal to 3."
  }
}

variable "create_key_name" {
  description = "The name of the SSH key to create"
  type        = string
}

variable "ssh_public_key" {
  description = "The public key to use when creating an SSH key"
  type        = string
}

variable "ssh_ingress_cidrs" {
  description = "The ingress cidrs for SSH to nodes"
  type        = list(string)
}

variable "kms_admin_arns" {
  description = "A list of ARNs for roles or users that should be able to administer the key but not use it"
  type        = list(string)
  default     = null
}

variable "kms_policy_statements" {
  description = "A map of policy statements to apply to the kms key use for vault unsealing"
  type = map(object({
    sid    = string
    effect = string
    principals = list(object({
      type        = string
      identifiers = list(string)
    }))
    actions = list(string)
    conditions = optional(list(object({
      test     = string
      variable = string
      values   = list(string)
    })), [])
  }))
  default = null
}
variable "enterprise_license_bucket" {
  description = "The name of the bucket where the enterprise license file is stored"
  type        = string
  default     = null
}

variable "enterprise_license_s3_key" {
  description = "The name of the s3 key to use for the enterprise license"
  type        = string
  default     = "vault.hclic"
}

variable "subnet_ids" {
  description = "The list of subnet IDs to use when deploying vault"
  type        = list(string)
}

variable "vpc_id" {
  description = "The VPC where the cluster will be deployed"
  type        = string
}

variable "tags" {
  description = "A map of key value tags to apply to all AWS resources"
  type        = map(string)
}


variable "log_retention" {
  description = "The log retention for vault server logs"
  type        = number
  default     = 731 # 2 years
}

variable "load_balancer_ingress_cidrs" {
  description = "The ingress cidrs to allow for the load balancer"
  type        = list(string)
}

variable "health_check_path" {
  description = "The path to use for health checks.  For uninitialized nodes, use /v1/sys/health?activecode=200&standbycode=200&sealedcode=200&uninitcode=200 for the health_check_path."
  type        = string
  default     = "/v1/sys/health"
}

variable "health_check_matcher" {
  description = "The health check codes to map against. Add 472 for DR replicas"
  type        = string
  default     = "200"
}

variable "bucket" {
  description = "The name of the s3 bucket to create for backup"
  type        = string
}

variable "sse" {
  description = "The type of encryption to use on the s3 bucket"
  type        = string
  default     = "AES256"
}

variable "force_destroy" {
  description = "Set to true if you want terraform to destroy the bucket, even if it has data"
  type        = bool
  default     = false
}

variable "s3_policy_statements" {
  description = "A map of policy statements for the s3 bucket"
  type = map(object({
    sid    = string
    effect = string
    principals = optional(list(object({
      type        = string
      identifiers = list(string)
    })))
    not_principals = optional(list(object({
      type        = string
      identifiers = list(string)
    })))
    actions       = optional(list(string))
    not_actions   = optional(list(string))
    resources     = optional(list(string), [])
    not_resources = optional(list(string))
    conditions = optional(list(object({
      test     = string
      variable = string
      values   = list(string)
    })))
  }))
  default = {}
}
variable "iam_assume_role_policies" {
  description = "A map of assume role policies for the iam role"
  type = map(object({
    sid    = optional(string)
    effect = optional(string, "Allow")
    principals = list(object({
      type        = string
      identifiers = list(string)
    }))
    actions = list(string)
    conditions = optional(list(object({
      test     = string
      variable = string
      values   = list(string)
    })), null)
  }))
  default = {}
}

variable "iam_policy_attachments" {
  description = "A list of aws managed policies to attach to the iam role"
  type        = list(string)
  default     = []
}

variable "iam_policy_statements" {
  description = "A map of policy statements to apply to the iam role"
  type = map(object({
    sid         = optional(string)
    effect      = optional(string, "Allow")
    actions     = list(string)
    not_actions = optional(list(string))
    resources   = optional(list(string))
    conditions = optional(list(object({
      test     = string
      variable = string
      values   = list(string)
    })))
  }))
  default = {}
}

variable "max_session_duration" {
  description = "The max session duration for the iam role"
  type        = number
  default     = 3600
}

variable "vault_name" {
  description = "The name of the vault cluster you wish to create"
  type        = string
}

variable "vault_binary" {
  description = "Whether to use vault enterprise or not"
  type        = string
  default     = "vault"

  validation {
    condition     = contains(["vault", "vault-enterprise"], var.vault_binary)
    error_message = "The only supported values for vault_binary are `vault` and `vault-enterprise`."
  }
}

variable "vault_version" {
  description = "The version of vault to install"
  type        = string
}

variable "auto_join_tag_key" {
  description = "The AWS tag key to use for node self discovery"
  type        = string
  default     = null
}

variable "auto_join_tag_value" {
  description = "The AWS tag value to use for node self discovery"
  type        = string
  default     = "server"
}

variable "disable_performance_standby" {
  description = "Whether to disable performance standby"
  type        = bool
  default     = true
}

variable "ui" {
  description = "Whether to enable the UI"
  type        = bool
  default     = true
}

variable "disable_mlock" {
  description = "Whether to disable mlock"
  type        = bool
  default     = true
}

variable "disable_sealwrap" {
  description = "Whether to disable sealwrap"
  type        = bool
  default     = true
}

variable "audit_log_path" {
  description = "The file path to the audit log"
  type        = string
  default     = "/opt/log/vault-audit.log"
}

variable "operator_log_path" {
  description = "The file path to the operator log"
  type        = string
  default     = "/var/log/vault-operator.log"
}
