resource "aws_elasticache_cluster" "sqlbook" {
  cluster_id           = aws_elasticache_subnet_group.sqlbook.name
  engine               = "redis"
  node_type            = "cache.t4g.micro"
  num_cache_nodes      = 1
  engine_version       = "7.1"
  port                 = 6379
  maintenance_window   = "mon:18:00-mon:20:00"
  subnet_group_name    = aws_elasticache_subnet_group.sqlbook.name
  parameter_group_name = aws_elasticache_parameter_group.sqlbook_7x.name
  security_group_ids   = [aws_security_group.elasticache.id]
}

resource "aws_elasticache_subnet_group" "sqlbook" {
  name       = "sqlbook"
  subnet_ids = [aws_subnet.public_1a.id, aws_subnet.public_1b.id, aws_subnet.public_1c.id]
}

resource "aws_elasticache_parameter_group" "sqlbook_7x" {
  name   = "${aws_elasticache_subnet_group.sqlbook.name}-redis7"
  family = "redis7"

  parameter {
    name  = "maxmemory-policy"
    value = "noeviction"
  }
}

resource "aws_security_group" "elasticache" {
  name   = "sqlbook-elasticache"
  vpc_id = aws_vpc.sqlbook.id
}

resource "aws_security_group_rule" "ingress_elasticache_ecs" {
  security_group_id        = aws_security_group.elasticache.id
  type                     = "ingress"
  protocol                 = "tcp"
  from_port                = aws_elasticache_cluster.sqlbook.port
  to_port                  = aws_elasticache_cluster.sqlbook.port
  source_security_group_id = aws_security_group.ecs_tasks.id
}
