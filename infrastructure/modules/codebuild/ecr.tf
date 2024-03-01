resource "aws_ecr_repository" "app" {
  name = var.name
}

resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.id
  policy     = <<EOF
   {
     "rules": [
       {
         "rulePriority": 1,
         "description": "Expires images older than 14 days",
         "selection": {
           "tagStatus": "untagged",
           "countType": "sinceImagePushed",
           "countUnit": "days",
           "countNumber": 14
         },
         "action": {
           "type": "expire"
         }
       }
     ]
   }
   EOF
}
