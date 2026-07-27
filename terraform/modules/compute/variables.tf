variable "project_name" {
  description = "Short name used to prefix/tag all resources"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID (from the networking module)"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private/app subnet IDs (from the networking module)"
  type        = list(string)
}

variable "db_address" {
  description = "RDS host address (from the database module)"
  type        = string
}

variable "db_port" {
  description = "RDS port (from the database module)"
  type        = number
}

variable "db_name" {
  description = "Database name (from the database module)"
  type        = string
}

variable "db_username" {
  description = "Database username"
  type        = string
}

variable "db_password" {
  description = "Database password — passed through to SSM Parameter Store as a SecureString"
  type        = string
  sensitive   = true
}
