resource "aws_s3_bucket" "terraform" {
  bucket = "terraform.sqlbook.com"
}

resource "aws_s3_bucket_versioning" "terraform_versioning" {
  bucket = aws_s3_bucket.terraform.id

  versioning_configuration {
    status = "Enabled"
  }
}
