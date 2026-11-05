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

module "ec2_cluster" {
  source = "./modules/ec2-cluster"

  project_name       = var.project_name
  private_subnet_ids = module.vpc.private_subnet_ids
  k3s_sg_id          = module.security_groups.k3s_sg_id

  # The nodes need the NAT route to download k3s on first boot.
  depends_on = [module.nat_instance]
}

module "rds" {
  source = "./modules/rds"

  project_name       = var.project_name
  private_subnet_ids = module.vpc.private_subnet_ids
  rds_sg_id          = module.security_groups.rds_sg_id
}

module "alb" {
  source = "./modules/alb"

  project_name      = var.project_name
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
  alb_sg_id         = module.security_groups.alb_sg_id
  asg_name          = module.ec2_cluster.asg_name
}

module "iam_oidc" {
  count  = var.enable_oidc ? 1 : 0
  source = "./modules/iam-oidc"

  project_name = var.project_name
  github_repo  = var.github_repo
  state_bucket = var.state_bucket
  lock_table   = var.lock_table
}
