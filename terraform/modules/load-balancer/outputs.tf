output "alb_dns_name" {
  description = "The ALB's public DNS name — this is the URL to actually visit the site"
  value       = aws_lb.app.dns_name
}

output "alb_security_group_id" {
  description = "ALB security group ID"
  value       = aws_security_group.alb.id
}
