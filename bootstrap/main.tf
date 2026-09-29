resource "aws_s3_bucket" "state" {
  # checkov:skip=CKV_AWS_18: log de acesso ao bucket exigiria um segundo
  # bucket só para isso. O acesso ao state já fica no CloudTrail da conta.
  # checkov:skip=CKV_AWS_144: replicação entre regiões dobra o custo e não se
  # justifica para o state de um laboratório destruído ao fim do uso.
  # checkov:skip=CKV_AWS_145: cifrado com SSE-S3 (AES256). Chave KMS própria
  # custa ~US$1/mês e se justifica só com exigência de controle da chave.
  # checkov:skip=CKV2_AWS_62: notificação de eventos não tem consumidor aqui.

  # bucket_prefix em vez de nome fixo: nome de bucket é único no mundo, e a
  # AWS completa o sufixo. Quem clona o projeto não precisa editar nada.
  bucket_prefix = "${var.project_name}-tfstate-"

  # Permite que o destroy apague o bucket com todas as versões do state.
  # Sem isso, o bucket versionado nunca fica vazio e sobra na conta.
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id

  # Cada apply gera uma versão nova do state. Se um state for corrompido ou
  # sobrescrito, a versão anterior pode ser restaurada.
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket = aws_s3_bucket.state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "state" {
  bucket = aws_s3_bucket.state.id

  # Desliga as ACLs: o acesso ao bucket passa a ser decidido só por IAM.
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  # Sem expiração, cada apply deixa uma versão antiga do state para sempre.
  rule {
    id     = "expire-noncurrent-version"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_version_retention_day
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
  }

  depends_on = [aws_s3_bucket_versioning.state]
}

# O state guarda endereços, ARNs e saídas do projeto. Esta política recusa
# qualquer acesso sem TLS, mesmo de quem tem permissão no bucket.
data "aws_iam_policy_document" "state" {
  statement {
    sid     = "DenyInsecureTransport"
    effect  = "Deny"
    actions = ["s3:*"]

    resources = [
      aws_s3_bucket.state.arn,
      "${aws_s3_bucket.state.arn}/*",
    ]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "state" {
  bucket = aws_s3_bucket.state.id
  policy = data.aws_iam_policy_document.state.json

  depends_on = [aws_s3_bucket_public_access_block.state]
}
