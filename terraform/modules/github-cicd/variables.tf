variable "project_name" {
  description = "Short name used to prefix/tag all resources"
  type        = string
}

variable "github_repo" {
  description = "Your GitHub repo in owner/repo format, e.g. kr3ativ3hustl3/vpc-guestbook"
  type        = string
}

variable "autoscaling_group_arn" {
  description = "ARN of the Auto Scaling Group this role is allowed to refresh (from the compute module)"
  type        = string
}
