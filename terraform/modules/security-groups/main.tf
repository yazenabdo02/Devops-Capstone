# ---------------- alb-sg: the only group open to the internet ----------------
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb-sg"
  description = "Public ALB: HTTP/HTTPS from the internet"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.project_name}-alb-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  description       = "HTTP from anywhere"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "alb_https" {
  security_group_id = aws_security_group.alb.id
  description       = "HTTPS from anywhere"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "alb_all" {
  security_group_id = aws_security_group.alb.id
  description       = "ALB to targets"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# ---------------- k3s-sg: reachable only from the ALB and from itself ----------------
resource "aws_security_group" "k3s" {
  name        = "${var.project_name}-k3s-sg"
  description = "k3s nodes: NodePorts from the ALB, node-to-node traffic"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.project_name}-k3s-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "k3s_from_alb" {
  security_group_id            = aws_security_group.k3s.id
  description                  = "NodePort range from the ALB only"
  ip_protocol                  = "tcp"
  from_port                    = 30000
  to_port                      = 32767
  referenced_security_group_id = aws_security_group.alb.id
}

resource "aws_vpc_security_group_ingress_rule" "k3s_self" {
  security_group_id            = aws_security_group.k3s.id
  description                  = "Node-to-node (API 6443, kubelet, flannel VXLAN)"
  ip_protocol                  = "-1"
  referenced_security_group_id = aws_security_group.k3s.id
}

resource "aws_vpc_security_group_egress_rule" "k3s_all" {
  security_group_id = aws_security_group.k3s.id
  description       = "Outbound via the NAT instance (ECR, SSM, packages)"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# ---------------- rds-sg: Postgres only from the k3s nodes ----------------
resource "aws_security_group" "rds" {
  name        = "${var.project_name}-rds-sg"
  description = "RDS PostgreSQL: 5432 from k3s nodes only"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.project_name}-rds-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "rds_from_k3s" {
  security_group_id            = aws_security_group.rds.id
  description                  = "PostgreSQL from k3s nodes"
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  referenced_security_group_id = aws_security_group.k3s.id
}

# ---------------- nat-sg: only traffic originating inside the VPC ----------------
resource "aws_security_group" "nat" {
  name        = "${var.project_name}-nat-sg"
  description = "NAT instance: accepts traffic from inside the VPC only"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.project_name}-nat-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "nat_from_vpc" {
  security_group_id = aws_security_group.nat.id
  description       = "All traffic from the VPC CIDR"
  ip_protocol       = "-1"
  cidr_ipv4         = var.vpc_cidr
}

resource "aws_vpc_security_group_egress_rule" "nat_all" {
  security_group_id = aws_security_group.nat.id
  description       = "NAT forwards outbound traffic to the internet"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}
