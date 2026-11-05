variable "project_name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "public_subnet_ids" {
  type = list(string)
}

variable "alb_sg_id" {
  type = string
}

variable "asg_name" {
  description = "Worker Auto Scaling Group the target group attaches to"
  type        = string
}

variable "node_port" {
  description = "NodePort Traefik listens on (fixed by the control-plane user-data)"
  type        = number
  default     = 30080
}
