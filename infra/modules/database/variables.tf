variable "name_prefix" {
  description = "Prefijo de los nombres de los recursos (por ejemplo ecobyte-dev). Debe empezar con ecobyte- para que los permisos por ARN del rol de despliegue lo alcancen"
  type        = string

  validation {
    condition     = can(regex("^ecobyte-[a-z0-9-]+$", var.name_prefix))
    error_message = "name_prefix debe empezar con ecobyte- y usar solo minúsculas, números y guiones."
  }
}

variable "ttl_attribute_name" {
  description = "Atributo de cada ítem con la fecha de vencimiento en segundos desde 1970 (epoch). DynamoDB borra el ítem cuando ese momento pasa; quien escribe el ítem calcula el valor (ahora más 30 días)"
  type        = string
  default     = "expires_at"

  validation {
    condition     = can(regex("^[A-Za-z][A-Za-z0-9_]*$", var.ttl_attribute_name))
    error_message = "ttl_attribute_name debe empezar con una letra y usar solo letras, números y guion bajo."
  }
}
