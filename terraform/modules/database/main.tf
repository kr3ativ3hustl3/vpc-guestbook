##############################################################################
# DATABASE MODULE
#
# Creates: a DB subnet group spanning the isolated database subnets,
# a security group that currently allows NO inbound traffic at all
# (the app tier's access rule gets added in Phase 4, once that tier
# exists), and the RDS Postgres instance itself.
##############################################################################

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = var.database_subnet_ids

  tags = {
    Name    = "${var.project_name}-db-subnet-group"
    Project = var.project_name
  }
}

##############################################################################
# Security group — deliberately empty of ingress rules right now.
# The rule allowing the app tier to connect gets added in Phase 4 as
# a separate `aws_security_group_rule`, once the app tier's security
# group actually exists to reference. Until then, this database is
# unreachable from anything, which is the correct, safe default state.
##############################################################################

resource "aws_security_group" "rds" {
  name        = "${var.project_name}-rds-sg"
  description = "RDS Postgres - no inbound rules yet, added in Phase 4"
  vpc_id      = var.vpc_id

  # Postgres itself needs no outbound access to function. Scoped to
  # HTTPS only, for any engine-level features that reach out (e.g.
  # extension metadata) — narrower than the original "-1/all ports"
  # rule Checkov (CKV_AWS_382) correctly flagged.
  egress {
    description = "HTTPS only"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project_name}-rds-sg"
    Project = var.project_name
  }
}

resource "aws_db_instance" "main" {
  #checkov:skip=CKV_AWS_157:Multi-AZ intentionally disabled - doubles RDS cost with no real users to justify it for this portfolio project; documented in docs/architecture.md.
  #checkov:skip=CKV_AWS_118:Enhanced Monitoring has a real per-metric CloudWatch cost beyond the free tier - deferred to keep this project's cost at $0 when not actively demoed.
  #checkov:skip=CKV_AWS_161:IAM database authentication would require the application itself to generate IAM auth tokens instead of a static password - an app-code change beyond this security-scanning pass's scope, tracked as a follow-up.
  #checkov:skip=CKV_AWS_129:Exporting logs to CloudWatch Logs incurs real ingestion/storage cost - deferred to avoid introducing a new billable destination.
  #checkov:skip=CKV_AWS_293:Deletion protection would block this project's established terraform destroy-after-verification workflow, used specifically to keep AWS costs at zero between work sessions.
  #checkov:skip=CKV2_AWS_60:copy_tags_to_snapshot is moot here - skip_final_snapshot=true means no snapshots are ever created to copy tags to.
  #checkov:skip=CKV2_AWS_30:Enabling Postgres query logging requires a new aws_db_parameter_group resource - genuinely new infrastructure, out of scope for a zero-new-infrastructure security pass.
  identifier     = "${var.project_name}-db"
  engine         = "postgres"
  engine_version = "16.4"
  instance_class = "db.t3.micro"

  allocated_storage = 20
  storage_type      = "gp2"

  # Encryption at rest via the AWS-managed default RDS key - genuinely
  # free, no reason not to have this on. Was previously unset.
  storage_encrypted = true

  # Explicit, not just relying on the provider default - documents
  # the actual intent rather than leaving it implicit.
  auto_minor_version_upgrade = true

  # Free for the standard 7-day retention window on RDS Postgres
  # (unlike Enhanced Monitoring, which does cost extra) - genuinely
  # no reason not to have this on either.
  performance_insights_enabled = true

  db_name  = "guestbook"
  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false

  # Single-AZ, not Multi-AZ — Multi-AZ doubles RDS cost for automatic
  # failover, which isn't worth it for a portfolio project's database.
  # A real production database serving actual users would want this on.
  multi_az = false

  backup_retention_period = 1
  skip_final_snapshot     = true
  deletion_protection     = false

  tags = {
    Name    = "${var.project_name}-db"
    Project = var.project_name
  }
}
