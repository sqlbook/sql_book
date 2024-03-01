variable "cluster_name" {
  type = string
}

variable "instance_count" {
  type = number
}

variable "docker_tag" {
  type = string
}

variable "load_balancer_name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "database_hostname" {
  type = string
}

variable "database_username" {
  type = string
}

variable "listener_arn" {
  type = string
}

variable "redis_url" {
  type = string
}