variable "name_prefix" {
  description = "Prefijo de los nombres de los recursos (por ejemplo ecobyte-dev). Debe empezar con ecobyte- para que los permisos por ARN del rol de despliegue lo alcancen"
  type        = string

  validation {
    condition     = can(regex("^ecobyte-[a-z0-9-]+$", var.name_prefix))
    error_message = "name_prefix debe empezar con ecobyte- y usar solo minúsculas, números y guiones."
  }
}

variable "source_dir" {
  description = "Carpeta con el código de la Lambda (app/lambda), que se comprime en un zip al planear"
  type        = string
}

variable "queue_arn" {
  description = "ARN de la cola de ingesta que dispara la Lambda"
  type        = string

  validation {
    condition     = startswith(var.queue_arn, "arn:aws:sqs:")
    error_message = "queue_arn debe ser el ARN de una cola SQS."
  }
}

variable "table_name" {
  description = "Nombre de la tabla de lecturas; la Lambda lo recibe como variable de entorno"
  type        = string
}

variable "table_arn" {
  description = "ARN de la tabla de lecturas, para acotar el permiso de escritura"
  type        = string

  validation {
    condition     = startswith(var.table_arn, "arn:aws:dynamodb:")
    error_message = "table_arn debe ser el ARN de una tabla DynamoDB."
  }
}

variable "ttl_attribute_name" {
  description = "Atributo de vencimiento que la Lambda escribe en cada ítem (fecha de la lectura más 30 días, en segundos desde 1970)"
  type        = string
}

variable "alerts_topic_arn" {
  description = "ARN del tópico SNS donde la Lambda publica las alertas de temperatura"
  type        = string

  validation {
    condition     = startswith(var.alerts_topic_arn, "arn:aws:sns:")
    error_message = "alerts_topic_arn debe ser el ARN de un tópico SNS."
  }
}

variable "alert_threshold_celsius" {
  description = "Temperatura a partir de la cual la Lambda publica una alerta"
  type        = number
  default     = 35
}

variable "lambda_timeout_seconds" {
  description = "Tiempo máximo de una invocación. El visibility timeout de la cola debe ser al menos 6 veces este valor; se revisa junto con el módulo messaging"
  type        = number
  default     = 30

  validation {
    condition     = var.lambda_timeout_seconds >= 1 && var.lambda_timeout_seconds <= 900
    error_message = "lambda_timeout_seconds debe estar entre 1 y 900."
  }
}

variable "memory_mb" {
  description = "Memoria de la Lambda. También fija la CPU; 128 MB alcanza para un consumidor que solo escribe en DynamoDB"
  type        = number
  default     = 128

  validation {
    condition     = var.memory_mb >= 128 && var.memory_mb <= 10240
    error_message = "memory_mb debe estar entre 128 y 10240."
  }
}

variable "batch_size" {
  description = "Mensajes de SQS que recibe la Lambda por invocación"
  type        = number
  default     = 10

  validation {
    condition     = var.batch_size >= 1 && var.batch_size <= 10
    error_message = "batch_size debe estar entre 1 y 10 (sin ventana de agrupamiento)."
  }
}

variable "max_concurrency" {
  description = "Máximo de Lambdas en paralelo que puede lanzar la cola. Se ajusta en la prueba de carga"
  type        = number
  default     = 5

  validation {
    condition     = var.max_concurrency >= 2 && var.max_concurrency <= 1000
    error_message = "max_concurrency debe estar entre 2 y 1000 (límite de SQS)."
  }
}

variable "log_retention_days" {
  description = "Días que se guardan los logs de la Lambda"
  type        = number
  default     = 7

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90], var.log_retention_days)
    error_message = "log_retention_days debe ser 1, 3, 5, 7, 14, 30, 60 o 90."
  }
}
