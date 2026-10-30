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

variable "github_sub_prefix" {
  description = "Prefijo del claim sub de los tokens OIDC de GitHub para este repo, con los IDs numéricos de dueño y repo (se ve con: gh api repos/<dueño>/<repo>/actions/oidc/customization/sub)"
  type        = string
  default     = "repo:maurobarrales25@131790697/ecobyte-agro@1436055208"

  validation {
    condition     = can(regex("^repo:[A-Za-z0-9-]+@[0-9]+/[A-Za-z0-9._-]+@[0-9]+$", var.github_sub_prefix))
    error_message = "github_sub_prefix debe tener el formato repo:dueño@ID/repo@ID."
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
