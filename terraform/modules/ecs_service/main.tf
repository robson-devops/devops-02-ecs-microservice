# O Container Insights grava as métricas num log group que a própria AWS cria
# se ele não existir — sem retenção e fora do Terraform, então ele sobrevive
# ao destroy. Criando antes, com o nome exato que o ECS usa, o ECS adota este
# log group e o destroy o remove.
resource "aws_cloudwatch_log_group" "container_insight" {
  # checkov:skip=CKV_AWS_158: cifrado com a chave gerenciada pela AWS; chave
  # KMS própria custa ~US$1/mês e não se justifica nesta escala.
  # checkov:skip=CKV_AWS_338: retenção curta em vez de 1 ano, por ser
  # ambiente efêmero.
  name              = "/aws/ecs/containerinsights/${var.name_prefix}/performance"
  retention_in_days = var.log_retention_day

  tags = {
    Name = "${var.name_prefix}-container-insight"
  }
}

resource "aws_ecs_cluster" "main" {
  name = var.name_prefix

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name = var.name_prefix
  }

  # No apply, o log group existe antes da primeira métrica; no destroy, o
  # cluster sai antes dele.
  depends_on = [aws_cloudwatch_log_group.container_insight]
}

resource "aws_cloudwatch_log_group" "main" {
  # checkov:skip=CKV_AWS_158: cifrado com a chave gerenciada pela AWS; chave
  # KMS própria custa ~US$1/mês e não se justifica nesta escala.
  # checkov:skip=CKV_AWS_338: retenção curta em vez de 1 ano, por ser
  # ambiente efêmero.
  name              = "/${var.name_prefix}/app"
  retention_in_days = var.log_retention_day

  tags = {
    Name = "${var.name_prefix}-log-group"
  }
}

# --- Identidades ---------------------------------------------------------
# Duas roles distintas, e a diferença importa:
#  - execution role: usada pelo agente do ECS ANTES do container subir, para
#    puxar imagem, escrever log e ler o secret do banco.
#  - task role: usada PELO container em execução. Aqui só permite o ECS Exec,
#    porque a aplicação não chama nenhuma API da AWS.

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "execution" {
  name               = "${var.name_prefix}-execution-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

resource "aws_iam_role_policy_attachment" "execution" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Permissão de ler exatamente um secret, não todos.
data "aws_iam_policy_document" "read_database_secret" {
  statement {
    effect    = "Allow"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [var.database_secret_arn]
  }
}

resource "aws_iam_role_policy" "read_database_secret" {
  name   = "${var.name_prefix}-read-database-secret"
  role   = aws_iam_role.execution.id
  policy = data.aws_iam_policy_document.read_database_secret.json
}

resource "aws_iam_role" "task" {
  name               = "${var.name_prefix}-task-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

# ECS Exec: abre sessão dentro do container sem SSH e sem bastion — mesmo
# princípio do acesso via SSM usado no projeto 1.
data "aws_iam_policy_document" "execute_command" {
  statement {
    effect = "Allow"
    actions = [
      "ssmmessages:CreateControlChannel",
      "ssmmessages:CreateDataChannel",
      "ssmmessages:OpenControlChannel",
      "ssmmessages:OpenDataChannel",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "execute_command" {
  name   = "${var.name_prefix}-execute-command"
  role   = aws_iam_role.task.id
  policy = data.aws_iam_policy_document.execute_command.json
}

# --- Rede das tasks ------------------------------------------------------

resource "aws_security_group" "task" {
  name        = "${var.name_prefix}-task-sg"
  description = "Tasks da aplicacao: entrada apenas do ALB"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.name_prefix}-task-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "from_alb" {
  security_group_id            = aws_security_group.task.id
  description                  = "Trafego da aplicacao vindo do ALB"
  referenced_security_group_id = var.alb_security_group_id
  from_port                    = var.application_port
  to_port                      = var.application_port
  ip_protocol                  = "tcp"

  tags = {
    Name = "${var.name_prefix}-task-ingress"
  }
}

resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.task.id
  description       = "Saida para ECR, CloudWatch, Secrets Manager e o banco"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"

  tags = {
    Name = "${var.name_prefix}-task-egress"
  }
}

# --- Task definition e serviço -------------------------------------------

resource "aws_ecs_task_definition" "main" {
  family                   = var.name_prefix
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn

  container_definitions = jsonencode([
    {
      name      = "app"
      image     = var.image
      essential = true

      portMappings = [
        {
          containerPort = var.application_port
          protocol      = "tcp"
        }
      ]

      environment = [
        { name = "DB_HOST", value = var.database_endpoint },
        { name = "DB_PORT", value = tostring(var.database_port) },
        { name = "DB_NAME", value = var.database_name },
        { name = "DB_USER", value = var.database_username },
        { name = "DB_SSLMODE", value = "require" },
      ]

      # A senha vem do Secrets Manager no momento em que a task sobe. Só a
      # chave "password" do JSON é injetada, e ela não aparece na task
      # definition nem no console.
      secrets = [
        {
          name      = "DB_PASSWORD"
          valueFrom = "${var.database_secret_arn}:password::"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.main.name
          "awslogs-region"        = data.aws_region.current.region
          "awslogs-stream-prefix" = "app"
        }
      }

      # Container não escreve em disco: a aplicação só serve HTTP e fala com o
      # banco. Com o sistema de arquivos somente leitura, quem invadir o
      # processo não consegue depositar binário nem alterar o código.
      readonlyRootFilesystem = true

      # /tmp precisa continuar gravável — bibliotecas usam para arquivo
      # temporário. É um volume efêmero, descartado com a task.
      mountPoints = [
        {
          sourceVolume  = "tmp"
          containerPath = "/tmp"
          readOnly      = false
        }
      ]
    }
  ])

  volume {
    name = "tmp"
  }

  tags = {
    Name = "${var.name_prefix}-task"
  }
}

data "aws_region" "current" {}

resource "aws_ecs_service" "main" {
  # checkov:skip=CKV_AWS_333: IP público na task é intencional. Sem ele seria
  # preciso NAT Gateway (~US$32/mês fixo) só para puxar imagem do ECR. A task
  # não aceita tráfego de ninguém além do ALB, por security group.
  name            = var.name_prefix
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.main.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  enable_execute_command = true

  # Rolling deploy sem downtime: nunca derruba abaixo do total saudável
  # (100%) e permite subir o dobro durante a troca.
  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200

  # Se o deploy não estabilizar, o ECS volta sozinho para a revisão anterior
  # em vez de deixar o serviço quebrado.
  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  network_configuration {
    subnets          = var.subnet_id
    security_groups  = [aws_security_group.task.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = var.target_group_arn
    container_name   = "app"
    container_port   = var.application_port
  }

  # Dá tempo da task subir e passar no health check antes do ALB considerar
  # que falhou.
  health_check_grace_period_seconds = 60

  # O pipeline registra novas revisões da task definition a cada deploy. Sem
  # isto, o próximo terraform apply reverteria a imagem em produção para a
  # que está no código. Trade-off documentado no README.
  lifecycle {
    ignore_changes = [task_definition, desired_count]
  }

  tags = {
    Name = "${var.name_prefix}-service"
  }
}
