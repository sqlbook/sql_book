resource "aws_ecs_service" "worker" {
  name                               = "worker"
  cluster                            = var.cluster_name
  task_definition                    = aws_ecs_task_definition.worker.arn
  desired_count                      = var.instance_count
  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 50
}

resource "aws_ecs_task_definition" "worker" {
  family        = "worker"
  task_role_arn = aws_iam_role.task_role.arn

  runtime_platform {
    cpu_architecture = "ARM64"
  }

  container_definitions = <<TASK
[
  {
    "name": "worker",
    "image": "404356446913.dkr.ecr.eu-west-1.amazonaws.com/sql_book:${var.docker_tag}",
    "cpu": 256,
    "memory": 512,
    "essential": true,
    "entryPoint": ["sh", "-c"],
    "command": ["bundle exec aws_sqs_active_job --queue events"],
    "runtimePlatform": {
      "cpuArchitecture": "ARM64"
    },
    "linuxParameters": {
      "initProcessEnabled": true
    },
    "portMappings": [
      {
        "containerPort": 3000
      }
    ],
    "environment": [
      {
        "name": "DATABASE_PRIMARY_URL",
        "value": "postgresql://sqlbook:${data.aws_ssm_parameter.sqlbook_rds_root_password.value}@${var.database_hostname}/sql_book_production"
      },
      {
        "name": "DATABASE_EVENTS_URL",
        "value": "postgresql://sqlbook:${data.aws_ssm_parameter.sqlbook_rds_root_password.value}@${var.database_hostname}/sql_book_events_production"
      },
      {
        "name": "DATABASE_READONLY_USERNAME",
        "value": "sql_book_readonly"
      },
      {
        "name": "DATABASE_READONLY_PASSWORD",
        "value": "${data.aws_ssm_parameter.sqlbook_rds_readonly_password.value}"
      },
      {
        "name": "SECRET_KEY_BASE",
        "value": "${data.aws_ssm_parameter.sqlbook_secret_key.value}"
      },
      {
        "name": "AWS_REGION",
        "value": "eu-west-1"
      },
      {
        "name": "REDIS_URL",
        "value": "${var.redis_url}"
      },
      {
        "name": "EVENTS_QUEUE_URL",
        "value": "${var.events_queue_url}"
      }
    ],
    "logConfiguration": {
      "logDriver": "awslogs",
      "options": {
        "awslogs-stream-prefix": "${var.cluster_name}",
        "awslogs-group": "${aws_cloudwatch_log_group.worker.name}",
        "awslogs-region": "eu-west-1"
      }
    }
  }
]
TASK
}

data "aws_ssm_parameter" "sqlbook_secret_key" {
  name = "sqlbook_secret_key"
}

data "aws_ssm_parameter" "sqlbook_rds_root_password" {
  name = "sqlbook_rds_root_password"
}

data "aws_ssm_parameter" "sqlbook_rds_readonly_password" {
  name = "sqlbook_rds_readonly_password"
}
