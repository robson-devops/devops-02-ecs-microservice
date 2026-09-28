resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.name_prefix}-vpc"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.name_prefix}-igw"
  }
}

# Subnets públicas: abrigam o ALB e as tasks do ECS. As tasks recebem IP
# público para puxar imagem do ECR sem NAT Gateway — decisão de custo
# documentada no README.
resource "aws_subnet" "public" {
  # checkov:skip=CKV_AWS_130: IP público é intencional. Sem ele as tasks
  # precisariam de NAT Gateway (~US$32/mês fixo) só para puxar imagem do ECR.
  # O que protege a task é o security group, que só aceita tráfego do ALB.
  for_each = var.public_subnet

  vpc_id                  = aws_vpc.main.id
  availability_zone       = each.value.availability_zone
  cidr_block              = each.value.cidr_block
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.name_prefix}-public-${each.key}"
    Tier = "public"
  }
}

# Subnets privadas: abrigam o RDS. Sem rota para a internet — o banco não
# precisa de saída, e o que não tem rota não é exposto por engano.
resource "aws_subnet" "private" {
  for_each = var.private_subnet

  vpc_id            = aws_vpc.main.id
  availability_zone = each.value.availability_zone
  cidr_block        = each.value.cidr_block

  tags = {
    Name = "${var.name_prefix}-private-${each.key}"
    Tier = "private"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.name_prefix}-public-rt"
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.name_prefix}-private-rt"
  }
}

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id
}

# O security group default de toda VPC nasce permitindo tráfego entre seus
# membros. Não usamos ele, mas deixá-lo aberto é um risco silencioso: qualquer
# recurso criado sem SG explícito cai nele. Este bloco o esvazia.
resource "aws_default_security_group" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.name_prefix}-default-sg-bloqueado"
  }
}

# Flow logs: registram o tráfego aceito e rejeitado da VPC. É o que permite
# responder "quem tentou falar com o banco?" depois do fato.
resource "aws_cloudwatch_log_group" "flow_log" {
  # checkov:skip=CKV_AWS_158: sem chave KMS própria. O CloudWatch já cifra em
  # repouso com chave gerenciada pela AWS; chave dedicada custa ~US$1/mês e só
  # se justifica quando há exigência de controle da chave pelo cliente.
  # checkov:skip=CKV_AWS_338: retenção de 14 dias, não de 1 ano. Flow log de
  # ambiente efêmero serve para depurar rede durante a vida do ambiente, não
  # para auditoria de longo prazo.
  count = var.enable_flow_log ? 1 : 0

  name              = "/${var.name_prefix}/vpc-flow-log"
  retention_in_days = var.flow_log_retention_day

  tags = {
    Name = "${var.name_prefix}-flow-log"
  }
}

data "aws_iam_policy_document" "flow_log_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "flow_log" {
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams",
    ]
    resources = ["${try(aws_cloudwatch_log_group.flow_log[0].arn, "")}:*"]
  }
}

resource "aws_iam_role" "flow_log" {
  count = var.enable_flow_log ? 1 : 0

  name               = "${var.name_prefix}-flow-log-role"
  assume_role_policy = data.aws_iam_policy_document.flow_log_assume_role.json
}

resource "aws_iam_role_policy" "flow_log" {
  count = var.enable_flow_log ? 1 : 0

  name   = "${var.name_prefix}-flow-log-policy"
  role   = aws_iam_role.flow_log[0].id
  policy = data.aws_iam_policy_document.flow_log.json
}

resource "aws_flow_log" "main" {
  count = var.enable_flow_log ? 1 : 0

  vpc_id               = aws_vpc.main.id
  traffic_type         = "ALL"
  iam_role_arn         = aws_iam_role.flow_log[0].arn
  log_destination_type = "cloud-watch-logs"
  log_destination      = aws_cloudwatch_log_group.flow_log[0].arn

  tags = {
    Name = "${var.name_prefix}-flow-log"
  }
}
