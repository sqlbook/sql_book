data "aws_ami" "ecs_latest" {
  owners      = ["amazon"]
  most_recent = true

  filter {
    name   = "name"
    values = ["amzn2-ami-ecs-hvm-2.0*"]
  }

  filter {
    name   = "architecture"
    values = ["arm64"]
  }
}


resource "aws_instance" "sqlbook" {
  ami                     = data.aws_ami.ecs_latest.id
  instance_type           = "t4g.small"
  availability_zone       = "eu-west-1a"
  iam_instance_profile    = aws_iam_instance_profile.sqlbook.name
  user_data               = base64encode(templatefile("${path.module}/userdata.tmpl", { cluster = "sqlbook" }))
  disable_api_termination = true
  vpc_security_group_ids  = [aws_security_group.sqlbook.id]
  subnet_id               = aws_subnet.public_1a.id

  tags = {
    Name = "sqlbook"
  }
}

resource "aws_iam_instance_profile" "sqlbook" {
  name = "sqlbook"
  role = aws_iam_role.sqlbook.name
}

resource "aws_iam_role" "sqlbook" {
  name               = "sqlbook"
  assume_role_policy = data.aws_iam_policy_document.role.json
}

data "aws_iam_policy_document" "role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "sqlbook" {
  name   = "sqlbook"
  role   = aws_iam_role.sqlbook.id
  policy = data.aws_iam_policy_document.policy.json
}

data "aws_iam_policy_document" "policy" {
  statement {
    actions = [
      "ecs:CreateCluster",
      "ecs:DeregisterContainerInstance",
      "ecs:DiscoverPollEndpoint",
      "ecs:Poll",
      "ecs:RegisterContainerInstance",
      "ecs:StartTelemetrySession",
      "ecs:Submit*",
      "ecr:GetAuthorizationToken",
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy_attachment" "sqlbook" {
  role       = aws_iam_role.sqlbook.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_security_group" "sqlbook" {
  name   = "sqlbook"
  vpc_id = aws_vpc.sqlbook.id
}

resource "aws_security_group_rule" "load_balancer" {
  security_group_id        = aws_security_group.sqlbook.id
  type                     = "ingress"
  description              = "Load Balancer"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.public_load_balancer.id
}

resource "aws_security_group_rule" "egress_http" {
  security_group_id = aws_security_group.sqlbook.id
  protocol          = "TCP"
  type              = "egress"
  description       = "HTTP"
  from_port         = 80
  to_port           = 80
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "egress_https" {
  security_group_id = aws_security_group.sqlbook.id
  protocol          = "TCP"
  type              = "egress"
  description       = "HTTPS"
  from_port         = 443
  to_port           = 443
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "egress_rds" {
  security_group_id        = aws_security_group.sqlbook.id
  type                     = "egress"
  description              = "RDS"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.rds.id
}

resource "aws_security_group_rule" "egress_redis" {
  security_group_id        = aws_security_group.sqlbook.id
  type                     = "egress"
  description              = "Redis"
  from_port                = 6379
  to_port                  = 6379
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.elasticache.id
}
