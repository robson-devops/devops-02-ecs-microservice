data "aws_caller_identity" "current" {}

data "aws_elb_service_account" "main" {}

# Bucket dos logs de acesso do ALB. Sem ele não há registro de quem chamou o
# quê — e é o primeiro artefato pedido em qualquer investigação de incidente.
resource "aws_s3_bucket" "access_log" {
  # checkov:skip=CKV_AWS_144: sem replicação entre regiões. Log de acesso de
  # ambiente de estudo não justifica o custo de replicação.
  # checkov:skip=CKV_AWS_18: o próprio bucket não tem log de acesso. Logar o
  # acesso ao bucket de log gera recursão de custo sem ganho aqui.
  # checkov:skip=CKV2_AWS_62: sem notificação de evento; nada consome estes
  # logs automaticamente neste projeto.
  # checkov:skip=CKV_AWS_145: cifrado com AES256 (chave gerenciada pela AWS);
  # chave KMS própria custa ~US$1/mês e não se justifica para log de acesso.
  bucket        = "${var.name_prefix}-alb-log-${data.aws_caller_identity.current.account_id}"
  force_destroy = true

  tags = {
    Name = "${var.name_prefix}-alb-log"
  }
}

resource "aws_s3_bucket_public_access_block" "access_log" {
  bucket                  = aws_s3_bucket.access_log.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "access_log" {
  bucket = aws_s3_bucket.access_log.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "access_log" {
  bucket = aws_s3_bucket.access_log.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "access_log" {
  bucket = aws_s3_bucket.access_log.id

  rule {
    id     = "expire-access-log"
    status = "Enabled"

    filter {}

    expiration {
      days = var.access_log_retention_day
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

data "aws_iam_policy_document" "access_log" {
  statement {
    effect    = "Allow"
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.access_log.arn}/*"]

    principals {
      type        = "AWS"
      identifiers = [data.aws_elb_service_account.main.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "access_log" {
  bucket = aws_s3_bucket.access_log.id
  policy = data.aws_iam_policy_document.access_log.json
}

resource "aws_security_group" "main" {
  name        = "${var.name_prefix}-alb-sg"
  description = "Entrada publica no ALB"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.name_prefix}-alb-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "public" {
  # checkov:skip=CKV_AWS_260: a porta pública do ALB precisa aceitar a
  # internet — é a função dele. Quem não aceita tráfego aberto é a task, que
  # só recebe deste security group.
  security_group_id = aws_security_group.main.id
  description       = "Trafego publico de entrada"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = var.listener_port
  to_port           = var.listener_port
  ip_protocol       = "tcp"

  tags = {
    Name = "${var.name_prefix}-alb-ingress"
  }
}

resource "aws_vpc_security_group_egress_rule" "to_task" {
  security_group_id = aws_security_group.main.id
  description       = "Saida do ALB para as tasks"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"

  tags = {
    Name = "${var.name_prefix}-alb-egress"
  }
}

resource "aws_lb" "main" {
  # checkov:skip=CKV_AWS_150: proteção contra exclusão desligada para que
  # terraform destroy funcione no laboratório. Em produção deve ser true.
  # checkov:skip=CKV2_AWS_28: sem WAF. Custa a partir de ~US$5/mês mais regra,
  # e não há superfície de aplicação que justifique nesta escala.
  # checkov:skip=CKV2_AWS_20: sem redirecionamento para HTTPS porque não há
  # listener HTTPS — ver a decisão declarada no README.
  name               = "${var.name_prefix}-alb"
  load_balancer_type = "application"
  internal           = false
  subnets            = var.subnet_id
  security_groups    = [aws_security_group.main.id]

  # Rejeita cabeçalho HTTP malformado em vez de repassar para a aplicação.
  drop_invalid_header_fields = true
  enable_deletion_protection = false

  access_logs {
    bucket  = aws_s3_bucket.access_log.id
    enabled = true
  }

  tags = {
    Name = "${var.name_prefix}-alb"
  }

  depends_on = [aws_s3_bucket_policy.access_log]
}

# target_type ip: no Fargate cada task tem ENI própria, então o alvo é o IP da
# task, não uma instância.
resource "aws_lb_target_group" "main" {
  # checkov:skip=CKV_AWS_378: HTTP entre ALB e task. Com TLS terminado na
  # borda, criptografar de novo até a task exige gerenciar certificado dentro
  # do container — fora do escopo deste nível.
  name        = "${var.name_prefix}-tg"
  port        = var.application_port
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.vpc_id

  # Espera a task drenar as conexões antes de ser removida. É o que evita
  # erro para o usuário durante o deploy.
  deregistration_delay = 30

  health_check {
    path                = var.health_check_path
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 15
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = {
    Name = "${var.name_prefix}-tg"
  }
}

resource "aws_lb_listener" "main" {
  # checkov:skip=CKV_AWS_2: listener em HTTP, sem TLS. Decisão declarada no
  # README: o domínio não tem DNS hospedado, então não há como validar
  # certificado ACM. HTTPS entra no projeto 5.
  # checkov:skip=CKV_AWS_103: política TLS não se aplica a listener HTTP.
  load_balancer_arn = aws_lb.main.arn
  port              = var.listener_port
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }

  tags = {
    Name = "${var.name_prefix}-listener"
  }
}
