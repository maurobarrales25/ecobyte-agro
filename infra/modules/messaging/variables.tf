variable "name_prefix" {
  description = "Prefijo de los nombres de los recursos (por ejemplo ecobyte-dev). Debe empezar con ecobyte- para que los permisos por ARN del rol de despliegue lo alcancen"
  type        = string

  validation {
    condition     = can(regex("^ecobyte-[a-z0-9-]+$", var.name_prefix))
    error_message = "name_prefix debe empezar con ecobyte- y usar solo minúsculas, números y guiones."
  }
}

variable "visibility_timeout_seconds" {
  description = "Tiempo que un mensaje queda oculto tras recibirse. Debe ser al menos 6 veces el timeout de la Lambda consumidora; se revisa junto con el módulo consumer"
  type        = number
  default     = 180

  validation {
    condition     = var.visibility_timeout_seconds >= 0 && var.visibility_timeout_seconds <= 43200
    error_message = "visibility_timeout_seconds debe estar entre 0 y 43200 (12 horas)."
  }
}

variable "max_receive_count" {
  description = "Intentos de recepción antes de que un mensaje pase a la DLQ"
  type        = number
  default     = 3

  validation {
    condition     = var.max_receive_count >= 1 && var.max_receive_count <= 1000
    error_message = "max_receive_count debe estar entre 1 y 1000."
  }
}

variable "message_retention_seconds" {
  description = "Tiempo que la cola de ingesta conserva un mensaje sin procesar"
  type        = number
  default     = 345600

  validation {
    condition     = var.message_retention_seconds >= 60 && var.message_retention_seconds <= 1209600
    error_message = "message_retention_seconds debe estar entre 60 segundos y 14 días (1209600)."
  }
}

variable "alert_emails" {
  description = "Correos que reciben las alertas del tópico SNS. Cada suscripción se confirma a mano desde el correo. Vacío: se crea el tópico sin suscriptores"
  type        = list(string)
  default     = []
}
