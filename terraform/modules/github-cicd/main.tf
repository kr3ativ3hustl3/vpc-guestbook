##############################################################################
# GITHUB CI/CD MODULE
#
# Lets GitHub Actions trigger a rolling deploy (an ASG "instance
# refresh") when app code changes — the running instances get
# replaced one at a time with new ones that re-run the startup
# script, which re-pulls the latest app code from GitHub's `main`
# branch. No SSH, no manual redeploy steps.
#
# Deliberately reuses the EXISTING GitHub OIDC provider rather than
# creating a new one. GitHub's OIDC provider is registered once per
# AWS ACCOUNT (not per-project) at the URL
# "https://token.actions.githubusercontent.com" — the Cloud Resume
# Challenge project already created one in this same account, and
# attempting to create a second would fail with "already exists" (see
# that project's docs/troubleshooting.md). A data source referencing
# the existing provider avoids that collision entirely.
##############################################################################

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

# Trust policy scoped to exactly this repo's `main` branch. Uses
# StringLike with a wildcard rather than StringEquals with an exact
# match — GitHub's OIDC subject claim includes numeric owner/repo IDs
# (e.g. "repo:owner@12345/repo@67890:ref:...") that StringEquals would
# never match. This exact bug cost significant debugging time on the
# Cloud Resume Challenge project before being traced by decoding an
# actual token — applying that lesson here from the start.
data "aws_iam_policy_document" "github_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${split("/", var.github_repo)[0]}*/${split("/", var.github_repo)[1]}*:ref:refs/heads/main"]
    }
  }
}

resource "aws_iam_role" "github_actions" {
  name               = "${var.project_name}-github-actions"
  assume_role_policy = data.aws_iam_policy_document.github_trust.json

  tags = {
    Project = var.project_name
  }
}

# Least-privilege: this role can ONLY start/check instance refreshes
# on THIS specific Auto Scaling Group — nothing else in the account.
resource "aws_iam_role_policy" "refresh_asg" {
  name = "${var.project_name}-refresh-asg"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "StartRefreshOnThisAsgOnly"
        Effect   = "Allow"
        Action   = ["autoscaling:StartInstanceRefresh"]
        Resource = var.autoscaling_group_arn
      },
      {
        Sid    = "DescribeActionsRequireWildcardResource"
        Effect = "Allow"
        Action = [
          "autoscaling:DescribeInstanceRefreshes",
          "autoscaling:DescribeAutoScalingGroups",
        ]
        Resource = "*"
      },
    ]
  })
}
