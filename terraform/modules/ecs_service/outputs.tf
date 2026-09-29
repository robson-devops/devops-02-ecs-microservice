output "cluster_arn" {
  description = "ARN do cluster ECS, usado como condição na policy do pipeline"
  value       = aws_ecs_cluster.main.arn
}

output "role_arn" {
  description = "ARNs das roles de execução e da task, sobre as quais o pipeline precisa de iam:PassRole"
  value       = [aws_iam_role.execution.arn, aws_iam_role.task.arn]
}

output "service_arn" {
  description = "ARN do serviço ECS, usado para restringir o UpdateService da policy do pipeline"
  value       = aws_ecs_service.main.id
}

output "cluster_name" {
  description = "Nome do cluster ECS, usado pelo pipeline no update-service"
  value       = aws_ecs_cluster.main.name
}

output "log_group_name" {
  description = "Nome do log group das tasks no CloudWatch"
  value       = aws_cloudwatch_log_group.main.name
}

output "security_group_id" {
  description = "ID do security group das tasks. É ele que o RDS autoriza como origem"
  value       = aws_security_group.task.id
}

output "service_name" {
  description = "Nome do serviço ECS, usado pelo pipeline no update-service"
  value       = aws_ecs_service.main.name
}

output "task_definition_family" {
  description = "Família da task definition, usada pelo pipeline ao registrar nova revisão"
  value       = aws_ecs_task_definition.main.family
}
