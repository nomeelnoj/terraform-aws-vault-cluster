terraform {
  required_version = ">= 1.4.5"
  required_providers {
    aws = {
      configuration_aliases = [
        aws.dns, aws.s3_enterprise_license
      ]
    }
  }
}
