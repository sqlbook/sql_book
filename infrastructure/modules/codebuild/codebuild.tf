resource "aws_codebuild_project" "app" {
  name          = var.name
  service_role  = aws_iam_role.app.arn
  description   = "docker"
  badge_enabled = true
  build_timeout = 15

  artifacts {
    type = "NO_ARTIFACTS"
  }

  logs_config {
    cloudwatch_logs {
      group_name = aws_cloudwatch_log_group.app.name
    }
  }

  environment {
    compute_type    = "BUILD_GENERAL1_SMALL"
    image           = "aws/codebuild/amazonlinux2-aarch64-standard:2.0"
    type            = "ARM_CONTAINER"
    privileged_mode = true

    environment_variable {
      name  = "AWS_DEFAULT_REGION"
      value = "eu-west-1"
    }

    environment_variable {
      name  = "IMAGE_REPO_NAME"
      value = var.name
    }
  }

  source {
    type                = "GITHUB"
    location            = "https://github.com/sqlbook/${var.name}.git"
    git_clone_depth     = 1
    report_build_status = true
  }
}

resource "aws_codebuild_webhook" "app" {
  project_name = aws_codebuild_project.app.name
  build_type   = "BUILD"

  filter_group {
    filter {
      type    = "EVENT"
      pattern = "PUSH"
    }

    filter {
      type    = "HEAD_REF"
      pattern = "main"
    }
  }
}

resource "aws_cloudwatch_log_group" "app" {
  name              = "/aws/codebuild/${var.name}"
  retention_in_days = 1
}
