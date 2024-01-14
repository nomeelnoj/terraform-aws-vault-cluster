terraform {
  required_version = ">= 1.6.6"

  backend "s3" {
    bucket  = "<name-of-state-bucket>"
    key     = "<path-to-state-file>"
    region  = "us-east-1"
    profile = "<aws-profile-name>"
    encrypt = "true"
  }
}

provider "aws" {
  region  = "us-east-1"
  profile = "default"
}

provider "aws" {
  region  = "us-east-1"
  profile = "shared-services"
  alias   = "central-account"
}

provider "aws" {
  region  = "us-east-1"
  profile = "network-services"
  alias   = "dns"
}

provider "vault" {
  address = "http://127.0.0.1:8200" # Set to local vault on initial scaffold, then to actual vault for non local cert generation
}
