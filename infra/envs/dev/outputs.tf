output "ingest_queue_url" {
  description = "URL de la cola de ingesta; el simulador la recibe por argumento o variable de entorno (tofu output -raw ingest_queue_url)"
  value       = module.messaging.ingest_queue_url
}
