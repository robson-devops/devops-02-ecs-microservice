output "role_arn" {
  description = "ARN da role que o GitHub Actions assume. Vai como secret AWS_ROLE_ARN no repositório"
  value       = aws_iam_role.pipeline.arn
}

output "role_name" {
  description = "Nome da role do pipeline"
  value       = aws_iam_role.pipeline.name
}
