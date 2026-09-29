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
