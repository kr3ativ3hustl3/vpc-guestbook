##############################################################################
# COMPUTE MODULE
#
# Creates: SSM Parameter Store entries for DB connection details, an
# IAM role/instance profile granting exactly the permissions instances
# need (SSM Session Manager + reading those specific parameters), a
# security group with NO inbound rules yet (Phase 4 adds the rule
# allowing traffic from the ALB), a launch template, and an Auto
# Scaling Group deploying the guestbook app into the private subnets.
##############################################################################

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Always-current Amazon Linux 2023 AMI, looked up via AWS's own public
# SSM parameter rather than a hardcoded AMI ID (which is region-
# specific and goes stale as new AMIs are released).
data "aws_ssm_parameter" "al2023_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

##############################################################################
# SSM Parameter Store — DB connection details, fetched by instances at
# boot via their IAM role. The password is a SecureString (encrypted
# with the AWS-managed SSM KMS key); everything else is a plain
# String since it isn't sensitive on its own.
##############################################################################

##############################################################################
# All five parameters use SecureString, encrypted with AWS's default
# SSM-managed KMS key (alias/aws/ssm) at no additional cost — even
# non-secret values (host, port, name, username) get encryption at
# rest, which costs nothing extra and is a genuine hardening over the
# String type used here originally.
##############################################################################

resource "aws_ssm_parameter" "db_host" {
  name  = "/${var.project_name}/db/host"
  type  = "SecureString"
  value = var.db_address
}

resource "aws_ssm_parameter" "db_port" {
  name  = "/${var.project_name}/db/port"
  type  = "SecureString"
  value = tostring(var.db_port)
}

resource "aws_ssm_parameter" "db_name" {
  name  = "/${var.project_name}/db/name"
  type  = "SecureString"
  value = var.db_name
}

resource "aws_ssm_parameter" "db_username" {
  name  = "/${var.project_name}/db/username"
  type  = "SecureString"
  value = var.db_username
}

resource "aws_ssm_parameter" "db_password" {
  name  = "/${var.project_name}/db/password"
  type  = "SecureString"
  value = var.db_password
}

##############################################################################
# IAM role — least-privilege: SSM Session Manager (the AWS-managed
# policy for that specific purpose) plus a hand-scoped policy allowing
# reads of ONLY the DB parameters above. No S3, no other services, no
# broad SSM access.
##############################################################################

resource "aws_iam_role" "ec2" {
  name = "${var.project_name}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })

  tags = {
    Project = var.project_name
  }
}

# AWS's own managed policy for SSM Session Manager access — the
# standard, recommended way to grant it, rather than a hand-rolled
# equivalent.
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy" "read_db_params" {
  name = "${var.project_name}-read-db-params"
  role = aws_iam_role.ec2.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = ["ssm:GetParameter"]
      Resource = "arn:aws:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter/${var.project_name}/db/*"
    }]
  })
}

resource "aws_iam_instance_profile" "ec2" {
  name = "${var.project_name}-ec2-profile"
  role = aws_iam_role.ec2.name
}

##############################################################################
# Security group — empty of ingress rules for now, same deferred
# pattern as the RDS security group in Phase 2. Phase 4 adds the rule
# allowing traffic from the ALB, once the ALB's security group exists.
##############################################################################

resource "aws_security_group" "app" {
  name        = "${var.project_name}-app-sg"
  description = "App tier - no inbound rules yet, added in Phase 4"
  vpc_id      = var.vpc_id

  # Scoped to exactly what the app tier needs outbound: HTTPS (SSM
  # agent, AWS API calls, AL2023 package repos) and Postgres (RDS).
  # Previously a single "-1/all ports" rule — Checkov (CKV_AWS_382)
  # correctly flags unrestricted egress as broader than necessary,
  # even though it's a lower-risk pattern than open ingress.
  egress {
    description = "HTTPS - SSM, AWS API, package repos"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Postgres to RDS"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project_name}-app-sg"
    Project = var.project_name
  }
}

##############################################################################
# Launch template + Auto Scaling Group
##############################################################################

resource "aws_launch_template" "app" {
  name_prefix   = "${var.project_name}-app-"
  image_id      = data.aws_ssm_parameter.al2023_ami.value
  instance_type = "t3.micro"

  vpc_security_group_ids = [aws_security_group.app.id]

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2.name
  }

  # No key_name set — deliberately no SSH key pair. Admin access is
  # via SSM Session Manager only (granted through the IAM role above),
  # so there's no SSH key to generate, distribute, or lose.
  user_data = base64encode(file("${path.module}/user_data.sh"))

  # Require IMDSv2 (session-token-based metadata requests) — blocks
  # the classic SSRF-to-credential-theft pattern that IMDSv1's
  # unauthenticated requests allow. Free, no functional downside for
  # this project's user_data (which already only reads metadata, no
  # writes).
  metadata_options {
    http_tokens   = "required"
    http_endpoint = "enabled"
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name    = "${var.project_name}-app"
      Project = var.project_name
    }
  }

  tags = {
    Project = var.project_name
  }
}

resource "aws_autoscaling_group" "app" {
  name                = "${var.project_name}-asg"
  min_size            = 2
  max_size            = 2
  desired_capacity    = 2
  vpc_zone_identifier = var.private_subnet_ids

  # ELB health checks — Phase 4 attaches this ASG to the ALB's target
  # group via a separate aws_autoscaling_attachment resource (avoids a
  # circular dependency between this module and the load-balancer
  # module — see docs/architecture.md). Once attached, ASG considers
  # an instance unhealthy if the ALB's health check on it fails, not
  # just basic EC2 status.
  health_check_type         = "ELB"
  health_check_grace_period = 300

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-app"
    propagate_at_launch = true
  }

  tag {
    key                 = "Project"
    value               = var.project_name
    propagate_at_launch = true
  }
}
