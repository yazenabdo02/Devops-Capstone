variable "project_name" {
  type = string
}

variable "subnet_id" {
  description = "Public subnet the NAT instance lives in"
  type        = string
}

variable "security_group_id" {
  type = string
}

variable "private_route_table_id" {
  description = "Private route table that gets a 0.0.0.0/0 route via this instance"
  type        = string
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}
