variable "aws_region" {
  description = "The region to which you are deploying"
  type        = string
  default     = "us-east-1"
}

variable "dns" {
  description = "All configuration values related to DNS"
  type = object({
    use_route53  = optional(bool, true)
    hosted_zone  = string
    hostname     = string
    private_zone = optional(bool, true)
  })
}

variable "cert" {
  description = "All configuration values for the SSL certs used by Vault and the load balancer"
  type = object({
    generate_local                = optional(bool, false)
    ttl                           = optional(string, "8760h")
    alt_names                     = optional(list(string))
    vault_pki_secret_backend_role = optional(string, "pki")
  })
  default = {}
}

variable "server" {
  description = "All configuration values for the vault servers"
  type = object({
    ami_id                      = optional(string)
    arch                        = optional(string, "arm64")
    root_device_name            = optional(string)
    create_key_name             = optional(string)
    ssh_public_key              = optional(string)
    key_name                    = optional(string)
    instance_type               = optional(string, "m7g.large")
    node_count                  = optional(number, 3)
    ssh_ingress_cidrs           = optional(list(string), [])
    ssh_ingress_security_groups = optional(list(string), [])
  })

  default = {}

  validation {
    condition     = contains(["arm64", "amd64"], var.server["arch"])
    error_message = "The only supported architectures at this time are 'arm64' and 'amd64'.  Make sure your instance type matches the architecture you have set."
  }

  validation {
    condition     = alltrue(flatten([for k, v in var.server : k == "ssh_ingress_cidrs" ? [for cidr in v : can(cidrhost(cidr, 0))] : [true]]))
    error_message = "All values in var.server[\"ssh_ingress_cidrs\"] must be valid CIDR objects."
  }

  validation {
    condition     = alltrue(flatten([for k, v in var.server : k == "ssh_ingress_security_groups" ? [for sg in v : can(regex("sg-.*", sg))] : [true]]))
    error_message = "All values in var.server[\"ssh_ingress_security_groups\"] must be valid security group IDs (e.g. sg-12345)."
  }

  validation {
    condition     = var.server["node_count"] % 2 == 1 && var.server["node_count"] >= 3
    error_message = "Node count must be an odd number greater than or equal to 3."
  }
}

variable "kms" {
  description = "All arguments related to KMS keys.  Module creates a key each for auto-unseal, cloudwatch, and s3 backups"
  type = object({
    admin_arns = list(string)
    policy_statements = optional(map(object({
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
    })), {})
  })
  default = null
}


variable "enterprise_license" {
  description = "Config values for the Enterprise license. Consists of an S3 bucket and s3 key where the license file exists."
  type = object({
    bucket_name = optional(string)
    s3_key      = optional(string)
  })
  default = {
    s3_key = "vault.hclic"
  }
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

variable "load_balancer" {
  description = "All configuration values for the load balancer. For uninitialized nodes, use /v1/sys/health?activecode=200&standbycode=200&sealedcode=200&uninitcode=200 for the health_check_path."
  type = object({
    health_check_matcher          = optional(string, "200,429")
    ingress_cidrs                 = optional(list(string))
    ingress_security_groups       = optional(list(string))
    additional_lb_security_groups = optional(list(string), [])
    health_check_path             = optional(string, "/v1/sys/health")
  })
  default = {}

  validation {
    condition     = alltrue([for cidr in var.load_balancer["ingress_cidrs"] : can(cidrhost(cidr, 0))])
    error_message = "All values in var.load_balancer[\"ingress_cidrs\"] must be valid CIDR objects."
  }

  validation {
    condition     = alltrue([for sg in var.load_balancer["ingress_security_groups"] : can(regex("sg-.*", sg))])
    error_message = "All values in var.load_balancer[\"ingress_security_groups\"] must be valid security group IDs (e.g. sg-12345)."
  }

  validation {
    condition     = alltrue([for sg in var.load_balancer["additional_lb_security_groups"] : can(regex("sg-.*", sg))])
    error_message = "All values in var.load_balancer[\"additional_lb_security_groups\"] must be valid security group IDs (e.g. sg-12345)."
  }
}

variable "s3" {
  description = "A map of all the various configuration values for the s3 bucket created to store backups."
  type = object({
    bucket        = string
    force_destroy = optional(bool, false)
    sse           = optional(string, "aws:kms")
    policy_statements = optional(map(object({
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
    })), {})
    kms_policy_statements = optional(map(object({
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
    })), {})
  })
}

variable "iam" {
  description = "A variable to contain all IAM information passed into the module"
  type = object({
    assume_role_policies = optional(map(object({
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
    })), {})
    max_session_duration = optional(number, 3600)
    policy_statements = optional(map(object({
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
    })), {})
  })
  default = {}
}

variable "vault_config" {
  description = "The vault config values to add to the userdata for populating /etc/vault/vault.hcl."
  type = object({
    vault_name                    = string
    vault_version                 = string
    auto_join_tag_key             = optional(string)
    auto_join_tag_value           = optional(string, "server")
    disable_performance_standby   = optional(bool, true)
    ui                            = optional(bool, true)
    disable_mlock                 = optional(bool, true)
    disable_sealwrap              = optional(bool, true)
    additional_server_configs     = optional(string, "")
    additional_server_tcp_configs = optional(string, "")
    audit_log_path                = optional(string, "/opt/vault/vault-audit.log")
    operator_log_path             = optional(string, "/var/log/vault-operator.log")
  })
}

