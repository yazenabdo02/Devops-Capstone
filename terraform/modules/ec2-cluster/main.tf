data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

# Shared secret that lets workers join the control-plane.
resource "random_password" "k3s_token" {
  length  = 48
  special = false
}

# ---------------- IAM: SSM access (no SSH keys) + ECR pull ----------------
resource "aws_iam_role" "node" {
  name = "${var.project_name}-k3s-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "ecr_read" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_instance_profile" "node" {
  name = "${var.project_name}-k3s-node-profile"
  role = aws_iam_role.node.name
}

# ---------------- k3s control-plane ----------------
resource "aws_instance" "control_plane" {
  ami                    = data.aws_ssm_parameter.al2023.value
  instance_type          = var.control_plane_instance_type
  subnet_id              = var.private_subnet_ids[0]
  vpc_security_group_ids = [var.k3s_sg_id]
  iam_instance_profile   = aws_iam_instance_profile.node.name

  user_data = templatefile("${path.module}/templates/control-plane-user-data.sh.tpl", {
    k3s_token = random_password.k3s_token.result
  })
  user_data_replace_on_change = true

  metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  tags = {
    Name = "${var.project_name}-k3s-control-plane"
    Role = "control-plane"
  }
}

# ---------------- k3s workers (Launch Template + ASG) ----------------
resource "aws_launch_template" "worker" {
  name_prefix   = "${var.project_name}-k3s-worker-"
  image_id      = data.aws_ssm_parameter.al2023.value
  instance_type = var.worker_instance_type

  vpc_security_group_ids = [var.k3s_sg_id]

  iam_instance_profile {
    name = aws_iam_instance_profile.node.name
  }

  user_data = base64encode(templatefile("${path.module}/templates/worker-user-data.sh.tpl", {
    k3s_token        = random_password.k3s_token.result
    control_plane_ip = aws_instance.control_plane.private_ip
  }))

  metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size = 20
      volume_type = "gp3"
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.project_name}-k3s-worker"
      Role = "worker"
    }
  }
}

resource "aws_autoscaling_group" "worker" {
  name                      = "${var.project_name}-k3s-workers"
  min_size                  = var.worker_min_size
  desired_capacity          = var.worker_desired_size
  max_size                  = var.worker_max_size
  vpc_zone_identifier       = var.private_subnet_ids
  health_check_type         = "EC2"
  health_check_grace_period = 300

  launch_template {
    id      = aws_launch_template.worker.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-k3s-worker"
    propagate_at_launch = true
  }
}
