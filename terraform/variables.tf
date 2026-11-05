variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "eu-north-1"
}

variable "project_name" {
  description = "Prefix used in resource names and tags"
  type        = string
  default     = "capstone"
}

variable "vpc_cidr" {
  description = "CIDR block of the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Two AZs to spread subnets across"
  type        = list(string)
  default     = ["eu-north-1a", "eu-north-1b"]
}

variable "public_subnet_cidrs" {
  description = "CIDRs of the public subnets (one per AZ)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDRs of the private subnets (one per AZ)"
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24"]
}

variable "github_repo" {
  description = "owner/name of the GitHub repo allowed to assume the CI/CD roles"
  type        = string
  default     = "yazenabdo02/Devops-Capstone"
}

variable "state_bucket" {
  type    = string
  default = "devops-capstone-tfstate-714370816085"
}

variable "lock_table" {
  type    = string
  default = "devops-capstone-tflock"
}

variable "enable_oidc" {
  description = "Create the GitHub OIDC provider and CI roles (blocked by an org SCP until the instructor allows it)"
  type        = bool
  default     = false
}
