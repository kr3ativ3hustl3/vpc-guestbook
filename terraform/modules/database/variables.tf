variable "project_name" {
  description = "Short name used to prefix/tag all resources"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID (from the networking module)"
  type        = string
}

variable "database_subnet_ids" {
  description = "Isolated database subnet IDs (from the networking module)"
  type        = list(string)
}

variable "db_username" {
  description = "Master username for the RDS instance"
  type        = string
}

variable "db_password" {
  description = "Master password for the RDS instance — set in terraform.tfvars, never commit it"
  type        = string
  sensitive   = true
}
