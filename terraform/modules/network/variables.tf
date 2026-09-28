variable "enable_flow_log" {
  description = "Habilita os flow logs da VPC no CloudWatch. Desligue apenas para reduzir custo em laboratório"
  type        = bool
  default     = true
}

variable "flow_log_retention_day" {
  description = "Dias de retenção dos flow logs no CloudWatch"
  type        = number
  default     = 14

  validation {
    condition     = var.flow_log_retention_day >= 1
    error_message = "A retenção deve ser de ao menos 1 dia."
  }
}

variable "name_prefix" {
  description = "Prefixo aplicado ao nome de todos os recursos criados pelo módulo"
  type        = string
}

variable "private_subnet" {
  description = <<-EOT
    Subnets privadas a criar, indexadas por uma chave estável (ex: "a", "b").
    A chave é usada no for_each, então renomeá-la recria a subnet.
    Não têm rota para a internet: destinam-se ao banco de dados.
  EOT
  type = map(object({
    availability_zone = string
    cidr_block        = string
  }))

  validation {
    condition     = length(var.private_subnet) >= 2
    error_message = "São necessárias ao menos duas subnets privadas: o subnet group do RDS exige duas AZs."
  }
}

variable "public_subnet" {
  description = <<-EOT
    Subnets públicas a criar, indexadas por uma chave estável (ex: "a", "b").
    A chave é usada no for_each, então renomeá-la recria a subnet.
  EOT
  type = map(object({
    availability_zone = string
    cidr_block        = string
  }))

  validation {
    condition     = length(var.public_subnet) >= 2
    error_message = "São necessárias ao menos duas subnets públicas: o ALB exige duas AZs."
  }
}

variable "vpc_cidr" {
  description = "CIDR block da VPC"
  type        = string
}
