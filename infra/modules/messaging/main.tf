# DLQ para mensajes que fallaron al procesarse
resource "aws_sqs_queue" "dlq" {
  name                      = "${var.name_prefix}-ingesta-dlq"
  message_retention_seconds = 1209600
  sqs_managed_sse_enabled   = true
}

# Cola de ingesta que recibe las lecturas del simulador. Luego de max_receive_count intentos fallidos, SQS mueve el mensaje a la DLQ.
resource "aws_sqs_queue" "ingest" {
  name                       = "${var.name_prefix}-ingesta"
  visibility_timeout_seconds = var.visibility_timeout_seconds
  message_retention_seconds  = var.message_retention_seconds
  sqs_managed_sse_enabled    = true

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = var.max_receive_count
  })
}

# Solo la cola de ingesta puede mandar mensajes a la DLQ.
resource "aws_sqs_queue_redrive_allow_policy" "dlq" {
  queue_url = aws_sqs_queue.dlq.id

  redrive_allow_policy = jsonencode({
    redrivePermission = "byQueue"
    sourceQueueArns   = [aws_sqs_queue.ingest.arn]
  })
}

# Tópico de alertas: temperatura sobre 35 °C y alarma de la DLQ. No se cifra porque las alarmas de CloudWatch no pueden publicar en un tópico cifrado con
# la clave gestionada por AWS . El tópico solo lleva textos de alerta, sin datos sensibles.
#trivy:ignore:AWS-0095
resource "aws_sns_topic" "alerts" {
  name = "${var.name_prefix}-alertas"
}

# El correo exige confirmación manual: SNS manda un mensaje y la suscripción queda pendiente hasta que alguien aprieta el enlace.
resource "aws_sns_topic_subscription" "email" {
  count = length(var.alert_emails)

  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_emails[count.index]
}
