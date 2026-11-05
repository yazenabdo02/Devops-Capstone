output "instance_id" {
  value = aws_instance.nat.id
}

output "public_ip" {
  value = aws_instance.nat.public_ip
}

output "network_interface_id" {
  value = aws_instance.nat.primary_network_interface_id
}
