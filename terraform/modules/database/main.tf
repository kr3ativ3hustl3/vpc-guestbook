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

  egress {
    description = "Allow all outbound (e.g. for engine patching)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project_name}-rds-sg"
    Project = var.project_name
  }
}

resource "aws_db_instance" "main" {
  identifier     = "${var.project_name}-db"
  engine         = "postgres"
  engine_version = "16.4"
  instance_class = "db.t3.micro"

  allocated_storage = 20
  storage_type      = "gp2"

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
