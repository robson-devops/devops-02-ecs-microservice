locals {
  oidc_url = "token.actions.githubusercontent.com"

  oidc_provider_arn = var.create_oidc_provider ? aws_iam_openid_connect_provider.github[0].arn : data.aws_iam_openid_connect_provider.github[0].arn

  repository_owner = split("/", var.github_repository)[0]
  repository_name  = split("/", var.github_repository)[1]

  # O GitHub emite o "sub" em dois formatos, dependendo de a organização usar
  # identificadores imutáveis:
  #   classico : repo:dono/repositorio:ref:refs/heads/main
  #   imutavel : repo:dono@<id>/repositorio@<id>:ref:refs/heads/main
  # O formato imutável anexa os IDs numéricos e protege contra alguém apagar e
  # recriar um repositório com o mesmo nome para herdar a confiança. A trust
  # policy aceita os dois, porque quem clona este projeto pode estar em
  # qualquer um dos casos.
  subject_pattern = [
    "repo:${var.github_repository}:ref:refs/heads/${var.github_branch}",
    "repo:${local.repository_owner}@*/${local.repository_name}@*:ref:refs/heads/${var.github_branch}",
  ]
}

# O provider é único por conta. O módulo cria ou apenas referencia, para que o
# projeto seja reproduzível tanto numa conta zerada quanto numa que já usa
# OIDC com o GitHub em outro repositório.
resource "aws_iam_openid_connect_provider" "github" {
  count = var.create_oidc_provider ? 1 : 0

  url             = "https://${local.oidc_url}"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["2b18947a6a9fc7764fd8b5fb18a863b0c6dac24f"]

  tags = {
    Name = "github-actions-oidc"
  }
}

data "aws_iam_openid_connect_provider" "github" {
  count = var.create_oidc_provider ? 0 : 1

  url = "https://${local.oidc_url}"
}

# A trust policy é a peça de segurança do OIDC. Sem a condição de "sub",
# qualquer workflow de qualquer repositório do GitHub poderia assumir a role.
data "aws_iam_policy_document" "assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_url}:aud"
      values   = ["sts.amazonaws.com"]
    }

    # StringLike, e não StringEquals, apenas por causa do curinga nos IDs
    # numéricos. O dono, o repositório e a branch continuam amarrados.
    condition {
      test     = "StringLike"
      variable = "${local.oidc_url}:sub"
      values   = local.subject_pattern
    }
  }
}

resource "aws_iam_role" "pipeline" {
  name                 = "${var.name_prefix}-pipeline-role"
  assume_role_policy   = data.aws_iam_policy_document.assume_role.json
  max_session_duration = 3600

  tags = {
    Name = "${var.name_prefix}-pipeline-role"
  }
}

data "aws_iam_policy_document" "pipeline" {
  # GetAuthorizationToken não aceita restrição por recurso: é a chamada que
  # devolve o token de login do registro, e vale para a conta inteira.
  statement {
    sid       = "EcrLogin"
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  # Publicação restrita ao repositório deste projeto.
  statement {
    sid    = "PushImageToProjectRepository"
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:PutImage",
      "ecr:BatchGetImage",
      "ecr:DescribeImages",
    ]
    resources = [var.ecr_repository_arn]
  }

  # RegisterTaskDefinition e DescribeTaskDefinition também não aceitam
  # restrição por recurso na API.
  statement {
    sid    = "RegisterTaskDefinition"
    effect = "Allow"
    actions = [
      "ecs:RegisterTaskDefinition",
      "ecs:DescribeTaskDefinition",
    ]
    resources = ["*"]
  }

  # Atualização limitada ao serviço deste projeto: o pipeline não consegue
  # mexer em nenhum outro serviço da conta.
  statement {
    sid    = "UpdateProjectService"
    effect = "Allow"
    actions = [
      "ecs:UpdateService",
      "ecs:DescribeServices",
    ]
    resources = [var.ecs_service_arn]

    condition {
      test     = "ArnEquals"
      variable = "ecs:cluster"
      values   = [var.ecs_cluster_arn]
    }
  }

  # PassRole é a permissão mais perigosa do conjunto: sem a condição de
  # serviço, quem a possui consegue atrelar qualquer role a um recurso e
  # escalar privilégio. Aqui vale só para as duas roles da task e só quando
  # quem recebe é o ECS.
  statement {
    sid       = "PassTaskRoles"
    effect    = "Allow"
    actions   = ["iam:PassRole"]
    resources = var.ecs_task_role_arn

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "pipeline" {
  name   = "${var.name_prefix}-pipeline-policy"
  role   = aws_iam_role.pipeline.id
  policy = data.aws_iam_policy_document.pipeline.json
}
