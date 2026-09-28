module "network" {
  source = "./modules/network"

  name_prefix    = local.name_prefix
  vpc_cidr       = var.vpc_cidr
  public_subnet  = local.public_subnet
  private_subnet = local.private_subnet
}
