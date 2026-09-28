module "network" {
  source = "./modules/network"

  name_prefix    = local.name_prefix
  vpc_cidr       = var.vpc_cidr
  public_subnet  = local.public_subnet
  private_subnet = local.private_subnet
}

module "ecr" {
  source = "./modules/ecr"

  name = local.name_prefix
}

module "rds" {
  source = "./modules/rds"

  name_prefix = local.name_prefix
  vpc_id      = module.network.vpc_id
  subnet_id   = module.network.private_subnet_id

  # Preenchido na etapa do ECS com o security group das tasks. Enquanto vazio,
  # o banco sobe sem nenhuma origem autorizada — que é o padrão seguro.
  allowed_security_group_id = []
}
