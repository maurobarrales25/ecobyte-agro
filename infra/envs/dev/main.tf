module "messaging" {
  source = "../../modules/messaging"

  name_prefix = "ecobyte-${var.env}"
}

module "database" {
  source = "../../modules/database"

  name_prefix = "ecobyte-${var.env}"
}
