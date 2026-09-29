locals {
  # Nome da instância. Também compõe o nome dos log groups, que precisa bater
  # exatamente com o que o RDS usa na exportação.
  identifier = "${var.name_prefix}-db"
}
