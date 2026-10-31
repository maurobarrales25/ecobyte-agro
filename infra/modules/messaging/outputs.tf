output "ingest_queue_url" {
  description = "URL de la cola de ingesta; la usa el simulador para enviar lecturas"
  value       = aws_sqs_queue.ingest.url
}

output "ingest_queue_arn" {
  description = "ARN de la cola de ingesta; el consumidor y el simulador lo usan para acotar permisos"
  value       = aws_sqs_queue.ingest.arn
}

output "ingest_queue_name" {
  description = "Nombre de la cola de ingesta, para las métricas de CloudWatch"
  value       = aws_sqs_queue.ingest.name
}

output "dlq_arn" {
  description = "ARN de la cola de mensajes fallidos"
  value       = aws_sqs_queue.dlq.arn
}

output "dlq_name" {
  description = "Nombre de la DLQ, para la alarma de CloudWatch"
  value       = aws_sqs_queue.dlq.name
}

output "alerts_topic_arn" {
  description = "ARN del tópico SNS de alertas"
  value       = aws_sns_topic.alerts.arn
}
