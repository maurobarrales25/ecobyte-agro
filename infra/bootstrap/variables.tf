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

variable "github_repository" {
  description = "Repositorio de GitHub que puede asumir los roles OIDC, con formato dueño/repo"
  type        = string
  default     = "maurobarrales25/ecobyte-agro"

  validation {
    condition     = can(regex("^[A-Za-z0-9-]+/[A-Za-z0-9._-]+$", var.github_repository))
    error_message = "github_repository debe tener el formato dueño/repo."
  }
}

variable "github_environment" {
  description = "Environment de GitHub (con aprobación manual) que puede asumir el rol de despliegue"
  type        = string
  default     = "dev"

  validation {
    condition     = can(regex("^[A-Za-z0-9._-]+$", var.github_environment))
    error_message = "github_environment solo admite letras, números, punto, guion y guion bajo."
  }
}
