output "dns_name" {
  description = "Nome DNS público do ALB, por onde a aplicação é acessada"
  value       = aws_lb.main.dns_name
}

output "security_group_id" {
  description = "ID do security group do ALB, usado como origem autorizada no security group das tasks"
  value       = aws_security_group.main.id
}

output "target_group_arn" {
  description = "ARN do target group onde o serviço ECS registra as tasks"
  value       = aws_lb_target_group.main.arn
}
