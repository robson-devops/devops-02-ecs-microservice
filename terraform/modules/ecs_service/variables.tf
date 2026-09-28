variable "alb_security_group_id" {
  description = "ID do security group do ALB. É a única origem autorizada a falar com as tasks"
  type        = string
}

variable "application_port" {
  description = "Porta em que o container escuta"
  type        = number
  default     = 8000
}

variable "cpu" {
  description = "Unidades de CPU da task Fargate. 256 equivale a 0,25 vCPU"
  type        = number
  default     = 256
}

variable "database_endpoint" {
  description = "Endereço do RDS, sem a porta"
  type        = string
}

variable "database_name" {
  description = "Nome do banco de dados"
  type        = string
}

variable "database_port" {
  description = "Porta do PostgreSQL"
  type        = number
  default     = 5432
}

variable "database_secret_arn" {
  description = "ARN do secret gerenciado pela AWS com as credenciais do banco. O ECS injeta apenas a chave password"
  type        = string
}

variable "database_username" {
  description = "Usuário do banco usado pela aplicação"
  type        = string
}

variable "desired_count" {
  description = "Quantidade de tasks em execução. Duas é o mínimo para sobreviver à perda de uma AZ"
  type        = number
  default     = 2

  validation {
    condition     = var.desired_count >= 2
    error_message = "São necessárias ao menos duas tasks para haver alta disponibilidade."
  }
}

variable "image" {
  description = "Imagem completa do container, incluindo a tag (ex: conta.dkr.ecr.regiao.amazonaws.com/app:sha)"
  type        = string
}

variable "log_retention_day" {
  description = "Dias de retenção dos logs das tasks no CloudWatch"
  type        = number
  default     = 14
}

variable "memory" {
  description = "Memória da task Fargate, em MiB. Precisa ser compatível com o valor de cpu"
  type        = number
  default     = 512
}

variable "name_prefix" {
  description = "Prefixo aplicado ao nome de todos os recursos criados pelo módulo"
  type        = string
}

variable "subnet_id" {
  description = "IDs das subnets onde as tasks serão criadas"
  type        = list(string)

  validation {
    condition     = length(var.subnet_id) >= 2
    error_message = "São necessárias subnets em ao menos duas AZs."
  }
}

variable "target_group_arn" {
  description = "ARN do target group do ALB onde as tasks se registram"
  type        = string
}

variable "vpc_id" {
  description = "ID da VPC onde o security group das tasks será criado"
  type        = string
}
