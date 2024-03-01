resource "aws_alb" "sqlbook" {
  name               = "sqlbook"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.public_load_balancer.id]
  subnets            = [aws_subnet.public_1a.id, aws_subnet.public_1b.id, aws_subnet.public_1c.id]
}

resource "aws_security_group" "public_load_balancer" {
  name        = "sqlbook-public-alb"
  description = "sqlbook-public-alb"
  vpc_id      = aws_vpc.sqlbook.id
}

resource "aws_security_group_rule" "load_balancer_to_ecs" {
  security_group_id = aws_security_group.public_load_balancer.id
  description       = "ECS"
  protocol          = "TCP"
  type              = "egress"
  from_port         = 0
  to_port           = 65535
  cidr_blocks       = [aws_vpc.sqlbook.cidr_block]
}

resource "aws_security_group_rule" "load_balancer_http" {
  security_group_id = aws_security_group.public_load_balancer.id
  description       = "HTTP"
  protocol          = "TCP"
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "load_balancer_https" {
  security_group_id = aws_security_group.public_load_balancer.id
  description       = "HTTPS"
  protocol          = "TCP"
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_alb_listener" "http" {
  load_balancer_arn = aws_alb.sqlbook.arn
  port              = 80

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_alb_listener" "https" {
  load_balancer_arn = aws_alb.sqlbook.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = aws_acm_certificate.sqlbook.arn

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
      host        = "sqlbook.com"
    }
  }
}

resource "aws_acm_certificate" "sqlbook" {
  domain_name       = "sqlbook.com"
  validation_method = "DNS"

  tags = {
    Name = "sqlbook"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "sqlbook_certificate" {
  for_each = {
    for dvo in aws_acm_certificate.sqlbook.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }
  allow_overwrite = true
  zone_id         = aws_route53_zone.sqlbook.id
  name            = each.value.name
  type            = each.value.type
  records         = [each.value.record]
  ttl             = 300
}

resource "aws_security_group" "ecs_tasks" {
  name   = "sqlbook-ecs-tasks-sg"
  vpc_id = aws_vpc.sqlbook.id

  ingress {
    protocol        = "tcp"
    from_port       = 0
    to_port         = 65535
    cidr_blocks     = ["0.0.0.0/0"]
    security_groups = [aws_security_group.public_load_balancer.id]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}
