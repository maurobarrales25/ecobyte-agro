output "budget_name" {
  description = "Nombre del presupuesto mensual"
  value       = aws_budgets_budget.monthly.name
}

output "budget_limit_usd" {
  description = "Límite mensual configurado, en USD"
  value       = var.budget_limit_usd
}

output "github_plan_role_arn" {
  description = "ARN del rol de solo lectura que asumen los pull requests para tofu plan"
  value       = aws_iam_role.github_plan.arn
}

output "github_deploy_role_arn" {
  description = "ARN del rol que asume el environment de GitHub para tofu apply y destroy"
  value       = aws_iam_role.github_deploy.arn
}
