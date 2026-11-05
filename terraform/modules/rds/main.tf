# RDS rejects '/', '@', '"' and spaces in passwords, so no special characters.
resource "random_password" "db" {
  length  = 24
  special = false
}

resource "aws_db_subnet_group" "this" {
  name       = "${var.project_name}-db-subnets"
  subnet_ids = var.private_subnet_ids

  tags = {
    Name = "${var.project_name}-db-subnets"
  }
}

resource "aws_db_parameter_group" "this" {
  name   = "${var.project_name}-pg16"
  family = "postgres16"

  tags = {
    Name = "${var.project_name}-pg16"
  }
}

resource "aws_db_instance" "this" {
  identifier = "${var.project_name}-postgres"

  engine         = "postgres"
  engine_version = "16"
  instance_class = var.instance_class

  allocated_storage = var.allocated_storage
  storage_type      = "gp2"
  storage_encrypted = true

  db_name  = var.db_name
  username = var.db_username
  password = random_password.db.result

  db_subnet_group_name   = aws_db_subnet_group.this.name
  parameter_group_name   = aws_db_parameter_group.this.name
  vpc_security_group_ids = [var.rds_sg_id]

  publicly_accessible = false
  multi_az            = false

  # Teaching project: fast create/destroy, no automated backups or final snapshot.
  backup_retention_period = 0
  skip_final_snapshot     = true
  deletion_protection     = false
  apply_immediately       = true

  tags = {
    Name = "${var.project_name}-postgres"
  }
}
