output "ecr_repository_url" {
  description = "URL do repositório ECR, usada no docker push do pipeline"
  value       = module.ecr.repository_url
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
