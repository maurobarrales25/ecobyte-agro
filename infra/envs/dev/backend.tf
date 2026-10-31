terraform {
  backend "s3" {
    bucket       = "ecobyte-agro-tfstate-852382801813"
    key          = "envs/dev/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
