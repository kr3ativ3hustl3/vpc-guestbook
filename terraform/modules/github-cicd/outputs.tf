output "role_arn" {
  description = "IAM role ARN GitHub Actions will assume via OIDC — paste into the GitHub secret AWS_GITHUB_ACTIONS_ROLE_ARN"
  value       = aws_iam_role.github_actions.arn
}
