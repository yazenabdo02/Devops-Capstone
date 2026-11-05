output "ci_role_arn" {
  value = aws_iam_role.ci.arn
}

output "terraform_role_arn" {
  value = aws_iam_role.terraform.arn
}
