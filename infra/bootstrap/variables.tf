variable "env" {
  description = "Nombre del entorno, usado en la etiqueta env"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "prod"], var.env)
    error_message = "env debe ser dev o prod."
  }
}

variable "budget_limit_usd" {
  description = "Límite mensual del presupuesto en USD"
  type        = number
  default     = 5

  validation {
    condition     = var.budget_limit_usd > 0
    error_message = "El límite debe ser mayor que 0."
  }
}
