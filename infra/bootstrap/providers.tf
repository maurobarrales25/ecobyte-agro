terraform {
  required_version = "= 1.12.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  backend "s3" {
    bucket       = "ecobyte-agro-tfstate-852382801813"
    key          = "bootstrap/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
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
