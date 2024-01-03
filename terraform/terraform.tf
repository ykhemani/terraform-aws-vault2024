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

    doormat = {
      source  = "doormat.hashicorp.services/hashicorp-security/doormat"
      version = "~> 0.0.2"
    }
  }
  required_version = ">= 1.5"
}
