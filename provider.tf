terraform {
  required_version = ">= 1.6.6"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.42"
      configuration_aliases = [
        aws.dns, aws.s3_enterprise_license
      ]
    }
    vault = {
      source  = "hashicorp/vault"
      version = ">= 4.1"
    }
    tls = {
      source  = "hashicorp/tls"
      version = ">= 4.0"
    }
    cloudinit = {
      source  = "hashicorp/cloudinit"
      version = ">= 2.3"
    }
  }
}
