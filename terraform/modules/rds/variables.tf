variable "allocated_storage_gb" {
  description = "Armazenamento inicial da instância, em GB. O mínimo do gp3 no RDS é 20"
  type        = number
  default     = 20

  validation {
    condition     = var.allocated_storage_gb >= 20
    error_message = "O armazenamento deve ser de ao menos 20 GB (mínimo do gp3 no RDS)."
  }
}

variable "allowed_security_group_id" {
  description = <<-EOT
    Security groups autorizados a conectar na porta do banco, indexados por um
    nome estável (ex: "task"). É mapa e não lista de propósito: os IDs só são
    conhecidos depois do apply, e o for_each exige que as CHAVES sejam
    estáticas. O banco nunca é exposto por CIDR, apenas por origem.
  EOT
  type        = map(string)
  default     = {}
}

variable "backup_retention_day" {
  description = "Dias de retenção dos backups automáticos. Zero desliga o backup"
  type        = number
  default     = 7

  validation {
    condition     = var.backup_retention_day >= 1
    error_message = "A retenção de backup deve ser de ao menos 1 dia."
  }
}

variable "database_name" {
  description = "Nome do banco de dados criado na instância"
  type        = string
  default     = "tasksdb"
}

variable "deletion_protection" {
  description = <<-EOT
    Impede que a instância seja destruída por engano. Falso por padrão para
    que terraform destroy funcione no laboratório; em produção deve ser true.
  EOT
  type        = bool
  default     = false
}

variable "engine_version" {
  description = "Versão maior do PostgreSQL. As versões menores sobem sozinhas via auto_minor_version_upgrade"
  type        = string
  default     = "16"
}

variable "instance_class" {
  description = "Classe da instância RDS"
  type        = string
  default     = "db.t4g.micro"
}

variable "log_export" {
  description = "Logs do PostgreSQL exportados para o CloudWatch. Cada um ganha um log group gerenciado pelo módulo"
  type        = list(string)
  default     = ["postgresql", "upgrade"]

  validation {
    condition     = alltrue([for log in var.log_export : contains(["postgresql", "upgrade", "iam-db-auth-error"], log)])
    error_message = "Valores aceitos pelo RDS PostgreSQL: postgresql, upgrade, iam-db-auth-error."
  }
}

variable "log_retention_day" {
  description = "Dias de retenção dos logs do banco no CloudWatch"
  type        = number
  default     = 14

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365], var.log_retention_day)
    error_message = "Use um dos valores de retenção aceitos pelo CloudWatch Logs (1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180 ou 365)."
  }
}

variable "master_username" {
  description = "Usuário administrador do banco. A senha é gerada e rotacionada pela AWS, nunca definida aqui"
  type        = string
  default     = "appadmin"
}

variable "multi_az" {
  description = <<-EOT
    Habilita réplica em outra AZ com failover automático. Dobra o custo da
    instância, então fica desligado por padrão em ambiente de estudo.
  EOT
  type        = bool
  default     = false
}

variable "name_prefix" {
  description = "Prefixo aplicado ao nome de todos os recursos criados pelo módulo"
  type        = string
}

variable "port" {
  description = "Porta em que o PostgreSQL escuta"
  type        = number
  default     = 5432
}

variable "skip_final_snapshot" {
  description = <<-EOT
    Descarta o snapshot final ao destruir a instância. Verdadeiro em ambiente
    de estudo, para que terraform destroy não deixe snapshot cobrando.
    Em produção isto deve ser falso.
  EOT
  type        = bool
  default     = true
}

variable "subnet_id" {
  description = "IDs das subnets privadas onde a instância será criada. Exige ao menos duas AZs"
  type        = list(string)

  validation {
    condition     = length(var.subnet_id) >= 2
    error_message = "O subnet group do RDS exige subnets em ao menos duas AZs."
  }
}

variable "vpc_id" {
  description = "ID da VPC onde o security group do banco será criado"
  type        = string
}
