variable "project_name" {
  type = string
}

variable "repositories" {
  description = "One ECR repository per component"
  type        = list(string)
  default     = ["auth-service", "catalog-service", "orders-service", "frontend"]
}

variable "keep_last_images" {
  type    = number
  default = 10
}
