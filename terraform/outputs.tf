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
