output "control_plane_instance_id" {
  value = aws_instance.control_plane.id
}

output "control_plane_private_ip" {
  value = aws_instance.control_plane.private_ip
}

output "asg_name" {
  value = aws_autoscaling_group.worker.name
}

output "node_role_name" {
  value = aws_iam_role.node.name
}
