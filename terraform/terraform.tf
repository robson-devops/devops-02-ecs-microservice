terraform {
  required_version = ">= 1.14"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Lock nativo do backend S3 (use_lockfile), disponível desde a 1.10 —
  # dispensa a tabela DynamoDB que antes era obrigatória para travar o state.
  backend "s3" {
    bucket       = "devops-02-tfstate-e88d7ee6"
    key          = "devops-02-ecs-microservice/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
