output "ecr_repository_url" {
  description = "URL do repositório ECR, usada no docker push do pipeline"
  value       = module.ecr.repository_url
}

output "pipeline_role_arn" {
  description = "ARN da role assumida pelo GitHub Actions. Configure como secret AWS_ROLE_ARN no repositório"
  value       = module.pipeline_identity.role_arn
}

output "ecs_cluster_name" {
  description = "Nome do cluster ECS, usado pelo pipeline"
  value       = module.ecs_service.cluster_name
}

output "ecs_service_name" {
  description = "Nome do serviço ECS, usado pelo pipeline"
  value       = module.ecs_service.service_name
}

output "ecs_task_definition_family" {
  description = "Família da task definition, usada pelo pipeline"
  value       = module.ecs_service.task_definition_family
}

output "application_url" {
  description = "URL pública da aplicação, via ALB"
  value       = "http://${module.alb.dns_name}"
}

output "database_endpoint" {
  description = "Endereço de conexão do RDS"
  value       = module.rds.endpoint
}

output "database_secret_arn" {
  description = "ARN do secret com as credenciais do banco, gerenciado pela AWS"
  value       = module.rds.master_user_secret_arn
}

output "private_subnet_id" {
  description = "IDs das subnets privadas"
  value       = module.network.private_subnet_id
}

output "public_subnet_id" {
  description = "IDs das subnets públicas"
  value       = module.network.public_subnet_id
}

output "vpc_id" {
  description = "ID da VPC do projeto"
  value       = module.network.vpc_id
}
