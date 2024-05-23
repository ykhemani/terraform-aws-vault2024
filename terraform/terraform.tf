terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }

    hcp = {
      source  = "hashicorp/hcp"
      version = "~> 0.90"
    }

    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }

    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }

    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
  required_version = "~> 1.8"
}
