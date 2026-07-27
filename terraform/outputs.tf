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
