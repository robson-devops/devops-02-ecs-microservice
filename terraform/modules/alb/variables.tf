variable "access_log_retention_day" {
  description = "Dias até os logs de acesso do ALB serem expirados no S3"
  type        = number
  default     = 30

  validation {
    condition     = var.access_log_retention_day >= 1
    error_message = "A retenção deve ser de ao menos 1 dia."
  }
}

variable "application_port" {
  description = "Porta em que o container da aplicação escuta"
  type        = number
  default     = 8000
}

variable "health_check_path" {
  description = <<-EOT
    Caminho consultado pelo target group. Usa a rota de readiness, que
    verifica o banco: uma task sem banco não deve receber tráfego.
  EOT
  type        = string
  default     = "/ready"
}

variable "listener_port" {
  description = "Porta pública do listener do ALB"
  type        = number
  default     = 80
}

variable "name_prefix" {
  description = "Prefixo aplicado ao nome de todos os recursos criados pelo módulo"
  type        = string
}

variable "subnet_id" {
  description = "IDs das subnets públicas onde o ALB será criado. Exige ao menos duas AZs"
  type        = list(string)

  validation {
    condition     = length(var.subnet_id) >= 2
    error_message = "O ALB exige subnets em ao menos duas AZs."
  }
}

variable "vpc_id" {
  description = "ID da VPC onde o ALB e seu security group serão criados"
  type        = string
}
