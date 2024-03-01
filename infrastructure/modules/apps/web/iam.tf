resource "aws_iam_role" "task_role" {
  name               = "sqlbook-web-task"
  assume_role_policy = data.aws_iam_policy_document.role.json
}

data "aws_iam_policy_document" "role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "task_role" {
  role   = aws_iam_role.task_role.id
  name   = aws_iam_role.task_role.name
  policy = data.aws_iam_policy_document.task_role.json
}

data "aws_iam_policy_document" "task_role" {
  statement {
    actions   = ["ses:SendEmail", "ses:SendRawEmail"]
    resources = [var.ses_domain_identity_arn]
  }

  statement {
    actions  = [
      "ssmmessages:CreateControlChannel",
      "ssmmessages:CreateDataChannel",
      "ssmmessages:OpenControlChannel",
      "ssmmessages:OpenDataChannel"
    ]

    resources = ["*"]
  }

  statement {
    actions  = ["sqs:SendMessage"]
    resources = [var.events_queue_arn]
  }
}
