output "table_name" {
  description = "Nombre de la tabla de lecturas; la Lambda lo recibe como variable de entorno"
  value       = aws_dynamodb_table.readings.name
}

output "table_arn" {
  description = "ARN de la tabla de lecturas; el consumidor lo usa para acotar su permiso de escritura"
  value       = aws_dynamodb_table.readings.arn
}

output "ttl_attribute_name" {
  description = "Atributo que DynamoDB usa para vencer los ítems; la Lambda lo escribe en cada lectura"
  value       = var.ttl_attribute_name
}
