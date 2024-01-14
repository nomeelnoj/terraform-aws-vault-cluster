terraform {
  required_version = ">= 1.6.6"
  required_providers {
    aws = {
      configuration_aliases = [
        aws.dns, aws.s3_enterprise_license
      ]
    }
  }
}
