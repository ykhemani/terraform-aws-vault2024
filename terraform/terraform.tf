terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }

    hcp = {
      source  = "hashicorp/hcp"
      version = ">= 0.71.0"
    }

    tls = {
      source  = "hashicorp/tls"
      version = ">= 4.0.5"
    }
  }
  required_version = ">= 1.6"
}
