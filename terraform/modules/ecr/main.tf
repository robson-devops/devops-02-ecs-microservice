resource "aws_ecr_repository" "main" {
  # checkov:skip=CKV_AWS_136: cifrado com AES256 (chave gerenciada pela AWS).
  # Chave KMS própria custa ~US$1/mês e só se justifica quando há exigência de
  # controle da chave pelo cliente, o que não é o caso deste projeto.
  name = var.name

  # IMMUTABLE: uma tag publicada nunca mais muda de conteúdo. É o que garante
  # que a imagem auditada é a mesma que está rodando. Consequência prática: o
  # pipeline publica apenas a tag do SHA do commit, nunca "latest".
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name = var.name
  }
}

# Sem lifecycle policy o repositório cresce para sempre e você paga
# armazenamento por imagens que ninguém vai usar de novo.
resource "aws_ecr_lifecycle_policy" "main" {
  repository = aws_ecr_repository.main.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expira imagens sem tag apos ${var.untagged_image_retention_day} dias"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = var.untagged_image_retention_day
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Mantem apenas as ${var.tagged_image_count} imagens com tag mais recentes"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = var.tagged_image_count
        }
        action = {
          type = "expire"
        }
      },
    ]
  })
}
