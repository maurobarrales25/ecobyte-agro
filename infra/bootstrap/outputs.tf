output "budget_name" {
  description = "Nombre del presupuesto mensual"
  value       = aws_budgets_budget.monthly.name
}

output "budget_limit_usd" {
  description = "Límite mensual configurado, en USD"
  value       = var.budget_limit_usd
}
