output "vpc_id" {
  description = "VPC ID"
  value       = module.networking.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnet IDs (for the ALB, later phases)"
  value       = module.networking.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private/app subnet IDs (for EC2, later phases)"
  value       = module.networking.private_subnet_ids
}

output "database_subnet_ids" {
  description = "Database subnet IDs (for RDS, later phases)"
  value       = module.networking.database_subnet_ids
}

output "db_endpoint" {
  description = "RDS connection endpoint"
  value       = module.database.db_endpoint
}

output "db_security_group_id" {
  description = "RDS security group ID — needed when wiring up the app tier in Phase 4"
  value       = module.database.security_group_id
}

output "app_security_group_id" {
  description = "App tier security group ID — needed in Phase 4 for the ALB and RDS rules"
  value       = module.compute.app_security_group_id
}

output "autoscaling_group_name" {
  description = "Auto Scaling Group name"
  value       = module.compute.autoscaling_group_name
}

output "site_url" {
  description = "The URL to actually visit the guestbook app"
  value       = "http://${module.load_balancer.alb_dns_name}"
}
