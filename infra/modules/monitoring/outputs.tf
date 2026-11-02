output "dashboard_name" {
  description = "Nombre del dashboard de CloudWatch, para buscarlo en la consola"
  value       = aws_cloudwatch_dashboard.pipeline.dashboard_name
}

output "dlq_alarm_arn" {
  description = "ARN de la alarma que avisa cuando hay mensajes en la DLQ"
  value       = aws_cloudwatch_metric_alarm.dlq_has_messages.arn
}
