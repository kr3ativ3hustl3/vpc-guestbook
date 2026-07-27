variable "project_name" {
  description = "Short name used to prefix/tag all resources"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID (from the networking module)"
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnet IDs the ALB will live in (from the networking module)"
  type        = list(string)
}

variable "app_security_group_id" {
  description = "App tier security group ID (from the compute module) — gets the new ingress rule allowing ALB traffic"
  type        = string
}

variable "db_security_group_id" {
  description = "RDS security group ID (from the database module) — gets the new ingress rule allowing app tier traffic"
  type        = string
}

variable "autoscaling_group_name" {
  description = "Auto Scaling Group name (from the compute module) — attached to this module's target group"
  type        = string
}
