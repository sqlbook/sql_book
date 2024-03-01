data "aws_iam_policy_document" "app" {
  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["*"]
  }

  statement {
    actions = [
      "ec2:CreateNetworkInterface",
      "ec2:CreateNetworkInterfacePermission",
      "ec2:DescribeDhcpOptions",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DeleteNetworkInterface",
      "ec2:DescribeSubnets",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeVpcs"
    ]
    resources = ["*"]
  }

  statement {
    actions = [
      "ecr:GetAuthorizationToken",
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:GetRepositoryPolicy",
      "ecr:DescribeRepositories",
      "ecr:ListImages",
      "ecr:DescribeImages",
      "ecr:BatchGetImage",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:PutImage"
    ]
    resources = ["*"]
  }

  statement {
    actions = [
      "lambda:UpdateFunctionCode"
    ]
    resources = ["*"]
  }

  statement {
    actions = [
      "ecs:UpdateService",
      "ecs:DescribeServices"
    ]
    resources = ["*"]
  }

  statement {
    actions = [
      "s3:PutObject",
      "s3:ListBucket",
      "s3:ListObjectsV2",
      "s3:DeleteObject"
    ]
    resources = [
      "arn:aws:s3:::cdn.sqlbook.com",
      "arn:aws:s3:::cdn.sqlbook.com/*"
    ]
  }
}

resource "aws_iam_role" "app" {
  name = "codebuild-${var.name}"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "codebuild.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "app" {
  role   = aws_iam_role.app.name
  policy = data.aws_iam_policy_document.app.json
}
