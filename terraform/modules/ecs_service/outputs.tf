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
