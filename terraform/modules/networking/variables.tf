variable "project_name" {
  description = "Short name used to prefix/tag all resources"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "availability_zones" {
  description = "List of 2 Availability Zones to spread subnets across"
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets, one per AZ"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private (app tier) subnets, one per AZ"
  type        = list(string)
}

variable "db_subnet_cidrs" {
  description = "CIDR blocks for database subnets, one per AZ"
  type        = list(string)
}
