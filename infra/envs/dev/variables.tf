variable "env" {
  description = "Nombre del entorno, usado en la etiqueta env"
  type        = string

  validation {
    condition     = contains(["dev", "prod"], var.env)
    error_message = "env debe ser dev o prod."
  }
}
