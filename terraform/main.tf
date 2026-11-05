module "vpc" {
  source = "./modules/vpc"

  project_name         = var.project_name
  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
}

module "security_groups" {
  source = "./modules/security-groups"

  project_name = var.project_name
  vpc_id       = module.vpc.vpc_id
  vpc_cidr     = module.vpc.vpc_cidr
}

module "nat_instance" {
  source = "./modules/nat-instance"

  project_name           = var.project_name
  subnet_id              = module.vpc.public_subnet_ids[0]
  security_group_id      = module.security_groups.nat_sg_id
  private_route_table_id = module.vpc.private_route_table_id
}

module "ecr" {
  source = "./modules/ecr"

  project_name = var.project_name
}
