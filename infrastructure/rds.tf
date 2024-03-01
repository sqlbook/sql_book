resource "aws_db_instance" "sqlbook" {
  identifier              = "sqlbook"
  allocated_storage       = 10
  db_name                 = "sqlbook"
  engine                  = "postgres"
  engine_version          = "16.1"
  instance_class          = "db.t4g.micro"
  username                = "sqlbook"
  password                = data.aws_ssm_parameter.sqlbook_rds_root_password.value
  parameter_group_name    = "default.postgres16"
  backup_retention_period = 7
  deletion_protection     = true
  skip_final_snapshot     = true
  db_subnet_group_name    = aws_db_subnet_group.sqlbook.name
  vpc_security_group_ids  = [aws_security_group.rds.id]
}

resource "aws_db_subnet_group" "sqlbook" {
  name       = "sqlbook"
  subnet_ids = [aws_subnet.public_1a.id, aws_subnet.public_1b.id, aws_subnet.public_1c.id]
}

data "aws_ssm_parameter" "sqlbook_rds_root_password" {
  name = "sqlbook_rds_root_password"
}

resource "aws_security_group" "rds" {
  name   = "sqlbook-rds"
  vpc_id = aws_vpc.sqlbook.id
}

resource "aws_security_group_rule" "ingress_rds_ecs" {
  security_group_id        = aws_security_group.rds.id
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.sqlbook.id
}
