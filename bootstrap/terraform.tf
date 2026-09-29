terraform {
  required_version = ">= 1.14"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Sem bloco backend de propósito: o state desta camada é local. Ela cria o
  # bucket onde fica o state do projeto, então não pode guardar o próprio
  # state nele. O arquivo terraform.tfstate fica em bootstrap/ e não é
  # versionado (.gitignore).
}
