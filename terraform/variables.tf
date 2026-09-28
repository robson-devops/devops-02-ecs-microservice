variable "application_port" {
  description = "Porta em que o container da aplicação escuta"
  type        = number
  default     = 8000
}

variable "aws_region" {
  description = "Região AWS onde a infraestrutura será provisionada"
  type        = string
  default     = "us-east-1"
}

variable "image_tag" {
  description = <<-EOT
    Tag da imagem usada na task definition inicial. O pipeline registra novas
    revisões a cada deploy, então este valor só vale para o primeiro apply.
    A imagem precisa existir no ECR antes do apply do serviço.
  EOT
  type        = string
  default     = "bootstrap"
}

variable "environment" {
  description = "Ambiente ao qual os recursos pertencem"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "O ambiente deve ser dev, staging ou prod."
  }
}

variable "project_name" {
  description = "Nome do projeto, usado como prefixo dos recursos e nas tags"
  type        = string
  default     = "devops-02"
}

variable "vpc_cidr" {
  description = "CIDR block da VPC. Precisa comportar as quatro subnets /24 derivadas dele"
  type        = string
  default     = "10.30.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0)) && tonumber(split("/", var.vpc_cidr)[1]) <= 20
    error_message = "vpc_cidr deve ser um CIDR válido com máscara /20 ou maior (ex: 10.30.0.0/16)."
  }
}
