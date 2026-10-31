terraform {
  required_version = "= 1.12.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = {
      project = "ecobyte-agro"
      team    = "ecobyte-agro"
      env     = var.env
      owner   = "mauro"
    }
  }
}
