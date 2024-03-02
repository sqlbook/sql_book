resource "aws_cloudwatch_log_group" "worker" {
  name              = "/ecs/sqlbook/worker"
  retention_in_days = 7
}
