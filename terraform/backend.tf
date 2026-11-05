terraform {
  backend "s3" {
    bucket         = "devops-capstone-tfstate-714370816085"
    key            = "capstone/terraform.tfstate"
    region         = "eu-north-1"
    dynamodb_table = "devops-capstone-tflock"
    encrypt        = true
  }
}
