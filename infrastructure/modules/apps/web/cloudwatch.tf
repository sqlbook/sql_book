resource "aws_cloudwatch_log_group" "web" {
  name              = "/ecs/sqlbook/web"
  retention_in_days = 30
}
