variable "create_oidc_provider" {
  description = <<-EOT
    Cria o provider OIDC do GitHub na conta. Ele é único por conta: se já
    existir de outro projeto, deixe falso e o módulo apenas o referencia.
    Criar um duplicado falha com EntityAlreadyExists.
  EOT
  type        = bool
  default     = false
}

variable "ecr_repository_arn" {
  description = "ARN do repositório ECR onde o pipeline publica a imagem"
  type        = string
}

variable "ecs_cluster_arn" {
  description = "ARN do cluster ECS onde o serviço roda"
  type        = string
}

variable "ecs_service_arn" {
  description = "ARN do serviço ECS que o pipeline atualiza"
  type        = string
}

variable "ecs_task_role_arn" {
  description = "ARNs das roles que a task definition referencia. O pipeline precisa de iam:PassRole sobre elas para registrar novas revisões"
  type        = list(string)
}

variable "github_branch" {
  description = "Branch autorizada a assumir a role. Qualquer outra referência do repositório é recusada"
  type        = string
  default     = "main"
}

variable "github_repository" {
  description = "Repositório no formato owner/nome. É o que a trust policy amarra"
  type        = string

  validation {
    condition     = can(regex("^[^/]+/[^/]+$", var.github_repository))
    error_message = "Use o formato owner/repositorio (ex: robson-devops/devops-02-ecs-microservice)."
  }
}

variable "name_prefix" {
  description = "Prefixo aplicado ao nome dos recursos criados pelo módulo"
  type        = string
}
