terraform {
  required_version = "1.7.4"

  backend "s3" {
    bucket  = "terraform.sqlbook.com"
    key     = "state.tf"
    profile = "sqlbook"
    region  = "eu-west-1"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
