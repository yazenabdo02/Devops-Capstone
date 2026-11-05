output "vpc_id" {
  value = module.vpc.vpc_id
}

output "public_subnet_ids" {
  value = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  value = module.vpc.private_subnet_ids
}

output "ecr_repository_urls" {
  value = module.ecr.repository_urls
}

output "control_plane_instance_id" {
  value = module.ec2_cluster.control_plane_instance_id
}

output "alb_dns_name" {
  value = module.alb.dns_name
}

output "rds_endpoint" {
  value = module.rds.endpoint
}

output "db_password" {
  value     = module.rds.password
  sensitive = true
}

output "ci_role_arn" {
  value = one(module.iam_oidc[*].ci_role_arn)
}

output "terraform_role_arn" {
  value = one(module.iam_oidc[*].terraform_role_arn)
}
