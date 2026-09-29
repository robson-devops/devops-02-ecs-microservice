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

module "alb" {
  source = "./modules/alb"

  name_prefix      = local.name_prefix
  vpc_id           = module.network.vpc_id
  subnet_id        = module.network.public_subnet_id
  application_port = var.application_port
}

module "rds" {
  source = "./modules/rds"

  name_prefix = local.name_prefix
  vpc_id      = module.network.vpc_id
  subnet_id   = module.network.private_subnet_id

  # Única origem autorizada a falar com o banco: as tasks da aplicação.
  allowed_security_group_id = {
    task = module.ecs_service.security_group_id
  }
}

module "pipeline_identity" {
  source = "./modules/pipeline_identity"

  name_prefix          = local.name_prefix
  github_repository    = var.github_repository
  create_oidc_provider = var.create_oidc_provider

  ecr_repository_arn = module.ecr.repository_arn
  ecs_cluster_arn    = module.ecs_service.cluster_arn
  ecs_service_arn    = module.ecs_service.service_arn
  ecs_task_role_arn  = module.ecs_service.role_arn
}

module "ecs_service" {
  source = "./modules/ecs_service"

  name_prefix      = local.name_prefix
  vpc_id           = module.network.vpc_id
  subnet_id        = module.network.public_subnet_id
  application_port = var.application_port

  alb_security_group_id = module.alb.security_group_id
  target_group_arn      = module.alb.target_group_arn

  image = "${module.ecr.repository_url}:${var.image_tag}"

  database_endpoint   = module.rds.endpoint
  database_port       = module.rds.port
  database_name       = module.rds.database_name
  database_username   = module.rds.master_username
  database_secret_arn = module.rds.master_user_secret_arn
}
