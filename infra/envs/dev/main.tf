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

# Lambda que consume la cola. El visibility timeout de la cola (180 s) es 6 veces el timeout
# de la Lambda (30 s): si se cambia uno, revisar el otro.
module "consumer" {
  source = "../../modules/consumer"

  name_prefix        = "ecobyte-${var.env}"
  source_dir         = "${path.root}/../../../app/lambda"
  queue_arn          = module.messaging.ingest_queue_arn
  alerts_topic_arn   = module.messaging.alerts_topic_arn
  table_name         = module.database.table_name
  table_arn          = module.database.table_arn
  ttl_attribute_name = module.database.ttl_attribute_name
}
