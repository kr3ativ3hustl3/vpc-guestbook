output "app_security_group_id" {
  description = "App tier security group ID — needed in Phase 4 to allow ALB traffic in and app traffic out to RDS"
  value       = aws_security_group.app.id
}

output "autoscaling_group_name" {
  description = "Auto Scaling Group name"
  value       = aws_autoscaling_group.app.name
}

output "autoscaling_group_arn" {
  description = "Auto Scaling Group ARN - used to scope the CI/CD IAM policy to exactly this ASG"
  value       = aws_autoscaling_group.app.arn
}

output "launch_template_id" {
  description = "Launch template ID"
  value       = aws_launch_template.app.id
}
