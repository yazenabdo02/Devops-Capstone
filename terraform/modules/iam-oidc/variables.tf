variable "project_name" {
  type = string
}

variable "github_repo" {
  description = "owner/name of the GitHub repo allowed to assume the roles"
  type        = string
}

variable "state_bucket" {
  type = string
}

variable "lock_table" {
  type = string
}

variable "create_oidc_provider" {
  description = "Set to false if the GitHub OIDC provider already exists in the account"
  type        = bool
  default     = true
}
