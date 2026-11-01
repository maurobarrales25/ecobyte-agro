output "ingest_queue_url" {
  description = "URL de la cola de ingesta; el simulador la recibe por argumento o variable de entorno (tofu output -raw ingest_queue_url)"
  value       = module.messaging.ingest_queue_url
}

output "consumer_function_name" {
  description = "Nombre de la Lambda consumidora"
  value       = module.consumer.function_name
}

output "consumer_log_group_name" {
  description = "Grupo de logs de la Lambda consumidora (aws logs tail <nombre> --follow)"
  value       = module.consumer.log_group_name
}
