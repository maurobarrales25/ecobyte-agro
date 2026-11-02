variable "name_prefix" {
  description = "Prefijo de los nombres de los recursos. Debe empezar con ecobyte- para que los permisos por ARN del rol de despliegue lo pueda utilizar"
  type        = string

  validation {
    condition     = can(regex("^ecobyte-[a-z0-9-]+$", var.name_prefix))
    error_message = "name_prefix debe empezar con ecobyte- y usar solo minúsculas y guiomes"
  }
}

variable "ingest_queue_name" {
  description = "Nombre de la cola de ingesta de SQS"
  type        = string

  validation {
    condition     = can(regex("^ecobyte-[a-z0-9-]+$", var.ingest_queue_name))
    error_message = "ingest_queue_name debe empezar con ecobyte- y usar solo minúsculas, numeros y guiones"
  }
}

variable "dlq_queue_name" {
  description = "Nombre de la DLQ de SQS"
  type        = string

  validation {
    condition     = can(regex("^ecobyte-[a-z0-9-]+$", var.dlq_queue_name))
    error_message = "dlq_queue_name debe empezar con ecobyte- y usar solo minúsculas, numeros y guiones"
  }
}

variable "lambda_function_name" {
  description = "Nombre de la función Lambda"
  type        = string

  validation {
    condition     = can(regex("^ecobyte-[a-z0-9-]+$", var.lambda_function_name))
    error_message = "lambda_function_name debe empezar con ecobyte- y usar solo minúsculas, numeros y guiones"
  }
}

variable "alerts_topic_arn" {
  description = "ARN del tópico SNS donde se publican las alertas"
  type        = string

  validation {
    condition     = startswith(var.alerts_topic_arn, "arn:aws:sns:")
    error_message = "alerts_topic_arn debe ser el ARN de un tópico SNS"
  }
}