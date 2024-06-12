terraform {
  required_version = ">= 1.8.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.53"
      configuration_aliases = [
        aws.dns, aws.s3_enterprise_license
      ]
    }
    vault = {
      source  = "hashicorp/vault"
      version = ">= 4.2"
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
