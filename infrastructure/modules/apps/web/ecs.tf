resource "aws_ecs_service" "web" {
  name                               = "web"
  cluster                            = var.cluster_name
  task_definition                    = aws_ecs_task_definition.web.arn
  desired_count                      = var.instance_count
  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 50

  load_balancer {
    container_name   = "web"
    container_port   = 3000
    target_group_arn = aws_lb_target_group.web.arn
  }
}

resource "aws_ecs_task_definition" "web" {
  family        = "web"
  task_role_arn = aws_iam_role.task_role.arn

  runtime_platform {
    cpu_architecture = "ARM64"
  }

  container_definitions = <<TASK
[
  {
    "name": "web",
    "image": "404356446913.dkr.ecr.eu-west-1.amazonaws.com/sql_book:${var.docker_tag}",
    "cpu": 256,
    "memory": 512,
    "essential": true,
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
        "name": "DATABASE_HOSTNAME",
        "value": "${var.database_hostname}"
      },
      {
        "name": "DATABASE_USERNAME",
        "value": "${var.database_username}"
      },
      {
        "name": "DATABASE_PASSWORD",
        "value": "${data.aws_ssm_parameter.sqlbook_rds_root_password.value}"
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
      }
    ],
    "logConfiguration": {
      "logDriver": "awslogs",
      "options": {
        "awslogs-stream-prefix": "${var.cluster_name}",
        "awslogs-group": "${aws_cloudwatch_log_group.web.name}",
        "awslogs-region": "eu-west-1"
      }
    }
  }
]
TASK
}

resource "aws_lb_target_group" "web" {
  target_type          = "instance"
  name                 = "web"
  port                 = 3000
  protocol             = "HTTP"
  vpc_id               = var.vpc_id
  deregistration_delay = 30

  health_check {
    protocol            = "HTTP"
    healthy_threshold   = 5
    unhealthy_threshold = 2
    path                = "/ping"
    matcher             = "200"
    timeout             = 5
  }
}

resource "aws_lb_listener_rule" "web" {
  listener_arn = var.listener_arn
  priority     = 1

  action {
    type = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }

  condition {
    host_header {
      values = ["sqlbook.com"]
    }
  }
}

data "aws_ssm_parameter" "sqlbook_secret_key" {
  name = "sqlbook_secret_key"
}

data "aws_ssm_parameter" "sqlbook_rds_root_password" {
  name = "sqlbook_rds_root_password"
}