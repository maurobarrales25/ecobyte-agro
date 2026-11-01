output "function_name" {
  description = "Nombre de la Lambda consumidora, para las métricas y alarmas de CloudWatch"
  value       = aws_lambda_function.consumer.function_name
}

output "function_arn" {
  description = "ARN de la Lambda consumidora"
  value       = aws_lambda_function.consumer.arn
}

output "log_group_name" {
  description = "Grupo de logs de la Lambda, para revisar las invocaciones"
  value       = aws_cloudwatch_log_group.consumer.name
}
