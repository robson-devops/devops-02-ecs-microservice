variable "aws_region" {
  description = "Região AWS do bucket de state. Precisa ser a mesma usada no backend do projeto"
  type        = string
  default     = "us-east-1"
}

variable "noncurrent_version_retention_day" {
  description = "Dias em que versões antigas do state ficam disponíveis para recuperação antes de expirar"
  type        = number
  default     = 30

  validation {
    condition     = var.noncurrent_version_retention_day >= 1
    error_message = "A retenção de versões antigas deve ser de ao menos 1 dia."
  }
}

variable "project_name" {
  description = "Nome do projeto, usado como prefixo do bucket e nas tags"
  type        = string
  default     = "devops-02"

  validation {
    condition     = can(regex("^[a-z0-9-]{3,18}$", var.project_name))
    error_message = "Use de 3 a 18 caracteres entre letras minúsculas, números e hífen (limite do prefixo de bucket S3)."
  }
}
