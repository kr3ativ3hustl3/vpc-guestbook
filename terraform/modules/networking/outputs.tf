output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets (for the ALB)"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of the private/app subnets (for EC2 instances)"
  value       = aws_subnet.private[*].id
}

output "database_subnet_ids" {
  description = "IDs of the database subnets (for RDS)"
  value       = aws_subnet.database[*].id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC — useful for security group rules"
  value       = aws_vpc.main.cidr_block
}
