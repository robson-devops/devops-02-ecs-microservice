terraform {
  required_version = ">= 1.14"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # O bucket é criado pela camada bootstrap/ e seu nome é passado no init:
  #   terraform init -backend-config="bucket=$(terraform -chdir=../bootstrap output -raw state_bucket_name)"
  # Nome de bucket é único no mundo, então não fica fixo no código.
  #
  # Lock nativo do backend S3 (use_lockfile), disponível desde a 1.10 —
  # dispensa a tabela DynamoDB que antes era obrigatória para travar o state.
  backend "s3" {
    key          = "devops-02-ecs-microservice/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
