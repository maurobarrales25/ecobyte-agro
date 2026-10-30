# Los correos no van en el repo: se cargan a mano una vez en SSM Parameter Store
# (SecureString, lista JSON) y cualquier integrante los lee con su usuario IAM.
data "aws_ssm_parameter" "budget_emails" {
  name = "/ecobyte/budget-emails"
}

locals {
  budget_emails = jsondecode(data.aws_ssm_parameter.budget_emails.value)
}

# Aviso por email cuando el gasto mensual de la cuenta se acerca al límite.
# No frena nada: solo alerta. Ver docs/finops para el porqué de no usar budget actions.
resource "aws_budgets_budget" "monthly" {
  name         = "ecobyte-monthly"
  budget_type  = "COST"
  limit_amount = tostring(var.budget_limit_usd)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  # La consola fija metrics = UnblendedCost, que es el valor por defecto. Declararlo
  # exige también filter_expression, así que se ignora para no generar diferencias.
  lifecycle {
    ignore_changes = [metrics]
  }

  # Avisos sobre gasto real al 50, 80 y 100 %.
  dynamic "notification" {
    for_each = [50, 80, 100]
    content {
      comparison_operator        = "GREATER_THAN"
      threshold                  = notification.value
      threshold_type             = "PERCENTAGE"
      notification_type          = "ACTUAL"
      subscriber_email_addresses = local.budget_emails
    }
  }

  # Aviso previo: AWS proyecta que se va a superar el límite.
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = local.budget_emails
  }
}
