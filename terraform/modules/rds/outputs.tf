output "database_name" {
  description = "Nome do banco de dados criado na instância"
  value       = aws_db_instance.main.db_name
}

output "endpoint" {
  description = "Endereço de conexão da instância, sem a porta"
  value       = aws_db_instance.main.address
}

output "master_user_secret_arn" {
  description = "ARN do secret gerenciado pela AWS com as credenciais do banco. É ele que o ECS injeta na task"
  value       = aws_db_instance.main.master_user_secret[0].secret_arn
}

output "master_username" {
  description = "Usuário administrador do banco"
  value       = aws_db_instance.main.username
}

output "port" {
  description = "Porta em que o PostgreSQL escuta"
  value       = aws_db_instance.main.port
}

output "security_group_id" {
  description = "ID do security group do banco, para anexar novas regras de origem"
  value       = aws_security_group.main.id
}
