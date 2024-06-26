resource "aws_ecs_cluster" "sqlbook" {
  name = "sqlbook"
}

module "web" {
  source = "./modules/apps/web"

  docker_tag              = "latest"
  instance_count          = 1
  cluster_name            = aws_ecs_cluster.sqlbook.name
  load_balancer_name      = aws_alb.sqlbook.name
  listener_arn            = aws_alb_listener.https.arn
  vpc_id                  = aws_vpc.sqlbook.id
  database_hostname       = aws_db_instance.sqlbook.endpoint
  redis_url               = "redis://${aws_elasticache_cluster.sqlbook.cache_nodes.0.address}:6379/0"
  events_queue_url        = aws_sqs_queue.events.url
  events_queue_arn        = aws_sqs_queue.events.arn
  ses_domain_identity_arn = aws_ses_domain_identity.sqlbook.arn
}

module "worker" {
  source = "./modules/apps/worker"

  docker_tag              = "latest"
  instance_count          = 1
  cluster_name            = aws_ecs_cluster.sqlbook.name
  vpc_id                  = aws_vpc.sqlbook.id
  database_hostname       = aws_db_instance.sqlbook.endpoint
  redis_url               = "redis://${aws_elasticache_cluster.sqlbook.cache_nodes.0.address}:6379/0"
  events_queue_url        = aws_sqs_queue.events.url
  events_queue_arn        = aws_sqs_queue.events.arn
  ses_domain_identity_arn = aws_ses_domain_identity.sqlbook.arn
}
