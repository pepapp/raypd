output "gha_plan_role_arn" {
  description = "Set as GitHub repo variable AWS_PLAN_ROLE_ARN."
  value       = aws_iam_role.gha_plan.arn
}

output "gha_apply_role_arn" {
  description = "Set as GitHub repo variable AWS_APPLY_ROLE_ARN."
  value       = aws_iam_role.gha_apply.arn
}
