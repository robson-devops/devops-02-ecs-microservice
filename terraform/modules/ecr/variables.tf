variable "force_delete" {
  description = <<-EOT
    Permite destruir o repositório mesmo com imagens dentro. Verdadeiro em
    ambiente efêmero, onde o terraform destroy falharia porque o pipeline
    publicou imagens que o Terraform não conhece. Em produção deve ser falso,
    para que apagar o repositório por engano não leve as imagens junto.
  EOT
  type        = bool
  default     = true
}

variable "name" {
  description = "Nome do repositório ECR"
  type        = string
}

variable "untagged_image_retention_day" {
  description = "Dias até uma imagem sem tag ser expirada pelo lifecycle policy"
  type        = number
  default     = 7

  validation {
    condition     = var.untagged_image_retention_day >= 1
    error_message = "A retenção deve ser de ao menos 1 dia."
  }
}

variable "tagged_image_count" {
  description = "Quantidade de imagens com tag mantidas no repositório antes da expiração das mais antigas"
  type        = number
  default     = 10

  validation {
    condition     = var.tagged_image_count >= 1
    error_message = "É preciso manter ao menos uma imagem com tag."
  }
}
