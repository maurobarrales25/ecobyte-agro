module "messaging" {
  source = "../../modules/messaging"

  name_prefix = "ecobyte-${var.env}"
}
