resource "aws_db_subnet_group" "main" {
  name       = "${var.name_prefix}-db"
  subnet_ids = var.subnet_id

  tags = {
    Name = "${var.name_prefix}-db-subnet-group"
  }
}

resource "aws_security_group" "main" {
  name        = "${var.name_prefix}-db-sg"
  description = "Acesso ao banco somente a partir dos security groups autorizados"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.name_prefix}-db-sg"
  }
}

# Regra por security group de origem, não por CIDR: quem pode falar com o banco
# é definido por identidade de recurso, não por faixa de IP.
resource "aws_vpc_security_group_ingress_rule" "database" {
  for_each = toset(var.allowed_security_group_id)

  security_group_id            = aws_security_group.main.id
  description                  = "PostgreSQL a partir do security group autorizado"
  referenced_security_group_id = each.value
  from_port                    = var.port
  to_port                      = var.port
  ip_protocol                  = "tcp"

  tags = {
    Name = "${var.name_prefix}-db-ingress"
  }
}

# Parameter group próprio para ligar o log de consultas. Sem ele não há como
# investigar consulta lenta depois do fato — o grupo default do RDS não loga.
resource "aws_db_parameter_group" "main" {
  name   = "${var.name_prefix}-postgres${var.engine_version}"
  family = "postgres${var.engine_version}"

  # DDL, não "all": registrar toda consulta significa gravar também os dados
  # que passam nelas, o que vira problema de privacidade e de volume de log.
  parameter {
    name  = "log_statement"
    value = "ddl"
  }

  # Consulta acima de 1s vai para o log. É o que revela lentidão sem gravar
  # o tráfego inteiro do banco.
  parameter {
    name  = "log_min_duration_statement"
    value = "1000"
  }

  # Rejeita conexão sem TLS. O tráfego entre a task e o banco atravessa a VPC,
  # mas "rede interna" não é garantia de confidencialidade.
  parameter {
    name  = "rds.force_ssl"
    value = "1"
  }

  parameter {
    name  = "log_connections"
    value = "1"
  }

  parameter {
    name  = "log_disconnections"
    value = "1"
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${var.name_prefix}-parameter-group"
  }
}

resource "aws_db_instance" "main" {
  # checkov:skip=CKV_AWS_157: multi_az é variável e fica desligado por padrão.
  # Réplica em outra AZ dobra o custo da instância e este é um ambiente de
  # estudo destruído ao fim da validação.
  # checkov:skip=CKV_AWS_226: sem chave KMS própria para os logs; o RDS já
  # cifra armazenamento e snapshots com chave gerenciada pela AWS.
  # checkov:skip=CKV_AWS_293: deletion_protection é variável e fica desligada
  # por padrão para que terraform destroy funcione no laboratório. Em produção
  # o valor deve ser true.
  # checkov:skip=CKV_AWS_118: enhanced monitoring desligado. O Performance
  # Insights já cobre a visibilidade de banco; o enhanced monitoring adiciona
  # métricas de SO e custo de ingestão que não se justificam nesta escala.
  # checkov:skip=CKV_AWS_354: Performance Insights usa a chave gerenciada pela
  # AWS; chave KMS própria só se justifica com exigência de controle da chave.
  # checkov:skip=CKV2_AWS_30: o log de consultas está ligado via parameter
  # group, mas com log_statement = ddl em vez de all. Registrar toda consulta
  # gravaria também os dados trafegados nelas.
  identifier     = "${var.name_prefix}-db"
  engine         = "postgres"
  engine_version = var.engine_version
  instance_class = var.instance_class

  db_name  = var.database_name
  username = var.master_username
  port     = var.port

  # A senha é gerada, guardada e rotacionada pela AWS no Secrets Manager.
  # Não existe variável de senha neste módulo, e nada de senha entra no state.
  manage_master_user_password = true

  allocated_storage     = var.allocated_storage_gb
  max_allocated_storage = var.allocated_storage_gb * 2
  storage_type          = "gp3"
  storage_encrypted     = true

  db_subnet_group_name   = aws_db_subnet_group.main.name
  parameter_group_name   = aws_db_parameter_group.main.name
  vpc_security_group_ids = [aws_security_group.main.id]
  multi_az               = var.multi_az
  publicly_accessible    = false

  backup_retention_period    = var.backup_retention_day
  copy_tags_to_snapshot      = true
  skip_final_snapshot        = var.skip_final_snapshot
  final_snapshot_identifier  = var.skip_final_snapshot ? null : "${var.name_prefix}-db-final"
  deletion_protection        = var.deletion_protection
  auto_minor_version_upgrade = true

  iam_database_authentication_enabled = true
  enabled_cloudwatch_logs_exports     = ["postgresql", "upgrade"]

  # 7 dias de retenção do Performance Insights é a faixa sem custo adicional.
  performance_insights_enabled          = true
  performance_insights_retention_period = 7

  tags = {
    Name = "${var.name_prefix}-db"
  }
}
