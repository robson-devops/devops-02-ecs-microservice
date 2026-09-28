output "repository_arn" {
  description = "ARN do repositório ECR, usado na policy da role OIDC do pipeline"
  value       = aws_ecr_repository.main.arn
}

output "repository_url" {
  description = "URL do repositório ECR, usada no docker push e na task definition"
  value       = aws_ecr_repository.main.repository_url
}
