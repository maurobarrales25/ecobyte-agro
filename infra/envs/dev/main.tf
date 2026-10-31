# Los correos no van en el repo: se cargan a mano una vez en SSM (SecureString, lista JSON).
data "aws_ssm_parameter" "alert_emails" {
  name = "/ecobyte/alert-emails"
}

module "messaging" {
  source = "../../modules/messaging"

  name_prefix  = "ecobyte-${var.env}"
  alert_emails = jsondecode(data.aws_ssm_parameter.alert_emails.value)
}

module "database" {
  source = "../../modules/database"

  name_prefix = "ecobyte-${var.env}"
}
