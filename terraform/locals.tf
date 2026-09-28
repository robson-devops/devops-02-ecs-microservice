locals {
  name_prefix = "${var.project_name}-${var.environment}"

  common_tag = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }

  # Duas AZs são obrigatórias: o ALB exige subnets em pelo menos duas, e o
  # subnet group do RDS também. É o que dá alta disponibilidade ao projeto.
  public_subnet = {
    a = {
      availability_zone = "${var.aws_region}a"
      cidr_block        = cidrsubnet(var.vpc_cidr, 8, 1)
    }
    b = {
      availability_zone = "${var.aws_region}b"
      cidr_block        = cidrsubnet(var.vpc_cidr, 8, 2)
    }
  }

  private_subnet = {
    a = {
      availability_zone = "${var.aws_region}a"
      cidr_block        = cidrsubnet(var.vpc_cidr, 8, 11)
    }
    b = {
      availability_zone = "${var.aws_region}b"
      cidr_block        = cidrsubnet(var.vpc_cidr, 8, 12)
    }
  }
}
