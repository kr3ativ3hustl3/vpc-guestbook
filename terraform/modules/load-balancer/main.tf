##############################################################################
# LOAD BALANCER MODULE
#
# Creates: the Application Load Balancer, its target group and
# listener, the attachment connecting the existing Auto Scaling Group
# to that target group, and the two security group rules deferred
# since Phase 2/3 — ALB -> app tier, and app tier -> RDS.
#
# Design note: connecting the ASG to the target group directly inside
# the compute module (Phase 3) would require the compute module to
# know the target group's ARN, which doesn't exist until THIS module
# creates it — but this module also needs the compute module's app
# security group ID and ASG name. That's a circular dependency, which
# Terraform doesn't allow between modules. The fix: `aws_autoscaling_
# attachment` is a separate resource that bridges an existing ASG
# (referenced by name) to a target group, without either module
# needing to reference the other bidirectionally.
##############################################################################

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

##############################################################################
# ALB security group — the first ingress rule in this whole project
# that actually allows traffic in from the public internet, and it's
# scoped to exactly port 80. Everything downstream of this (app tier,
# database) still only accepts traffic from the specific security
# group in front of it, never directly from the internet.
##############################################################################

resource "aws_security_group" "alb" {
  #checkov:skip=CKV_AWS_260:This is a public-facing website's load balancer - accepting HTTP from anywhere on port 80 is the entire point of it, not a misconfiguration. HTTPS is a separate, documented decision below (see the listener resource).
  name        = "${var.project_name}-alb-sg"
  description = "ALB - allows inbound HTTP from the internet"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Scoped to exactly the app tier's security group on the app port -
  # the ALB never needs to reach anything else. Previously an
  # unrestricted "-1/all ports, 0.0.0.0/0" rule.
  egress {
    description     = "App tier only"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [var.app_security_group_id]
  }

  tags = {
    Name    = "${var.project_name}-alb-sg"
    Project = var.project_name
  }
}

##############################################################################
# Application Load Balancer, target group, listener
##############################################################################

resource "aws_lb" "app" {
  #checkov:skip=CKV_AWS_91:Access logging needs a new S3 bucket destination - genuinely new infrastructure and storage cost, out of scope for a zero-new-infrastructure security pass.
  #checkov:skip=CKV_AWS_150:Deletion protection would block this project's established terraform destroy-after-verification workflow, used specifically to keep AWS costs at zero between work sessions.
  #checkov:skip=CKV2_AWS_20:HTTP-to-HTTPS redirect requires HTTPS itself (see CKV_AWS_2 below) - not possible without a registered domain.
  #checkov:skip=CKV2_AWS_28:WAF has a real recurring per-ACL and per-rule cost (~$5-10+/month) - deferred, out of scope for this project's cost-conscious design.
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.public_subnet_ids

  # Free, no functional downside — rejects malformed/ambiguous HTTP
  # headers instead of forwarding them, closing off a class of
  # request-smuggling techniques. Was previously unset.
  drop_invalid_header_fields = true

  tags = {
    Name    = "${var.project_name}-alb"
    Project = var.project_name
  }
}

resource "aws_lb_target_group" "app" {
  #checkov:skip=CKV_AWS_378:HTTP target group protocol is a direct consequence of the HTTPS decision below (CKV_AWS_2) - same root cause, same justification.
  name     = "${var.project_name}-tg"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    path                = "/health"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = {
    Name    = "${var.project_name}-tg"
    Project = var.project_name
  }
}

resource "aws_lb_listener" "http" {
  #checkov:skip=CKV_AWS_2:HTTPS requires a registered domain name + ACM certificate, which this project deliberately doesn't have (unlike project 1, which does own sunsetheard.dev) - a genuine scope decision, not an oversight.
  #checkov:skip=CKV_AWS_103:Same root cause as CKV_AWS_2 above - TLS policy is moot without an HTTPS listener to apply it to.
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

# Bridges the existing ASG (from Phase 3) to this target group —
# see the module-level comment above for why this is a separate
# resource rather than a direct reference in either module.
resource "aws_autoscaling_attachment" "app" {
  #checkov:skip=CKV2_AWS_15:Checkov flags this attachment resource because it can't see across module boundaries that the actual ASG (modules/compute/main.tf, referenced here only by name via var.autoscaling_group_name) already has health_check_type = "ELB" explicitly set. Verified directly in that file - this is a static-analysis visibility limitation, not a real gap.
  autoscaling_group_name = var.autoscaling_group_name
  lb_target_group_arn    = aws_lb_target_group.app.arn
}

##############################################################################
# The two security group rules deferred since Phase 2/3 — added now
# that both sides of each connection actually exist.
##############################################################################

resource "aws_security_group_rule" "app_from_alb" {
  type                     = "ingress"
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "tcp"
  security_group_id        = var.app_security_group_id
  source_security_group_id = aws_security_group.alb.id
  description              = "Allow ALB to reach the app tier"
}

resource "aws_security_group_rule" "rds_from_app" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = var.db_security_group_id
  source_security_group_id = var.app_security_group_id
  description              = "Allow the app tier to reach RDS"
}
