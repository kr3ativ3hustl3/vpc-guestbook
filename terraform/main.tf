##############################################################################
# ROOT MODULE — VPC Guestbook Project
#
# Reuses the SAME S3 bucket + DynamoDB lock table created for the
# Cloud Resume Challenge project's Terraform state — no need to set
# up a new state backend from scratch. The `key` below is what keeps
# this project's state completely separate from that one; think of it
# as a different file path within the same bucket.
##############################################################################

terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "sunificent-cloud-resume-tf-state-2026"
    key            = "vpc-guestbook/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "cloud-resume-tf-lock"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
}

module "networking" {
  source = "./modules/networking"

  providers = { aws = aws }

  project_name         = var.project_name
  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  db_subnet_cidrs      = var.db_subnet_cidrs
}

module "database" {
  source = "./modules/database"

  providers = { aws = aws }

  project_name        = var.project_name
  vpc_id              = module.networking.vpc_id
  database_subnet_ids = module.networking.database_subnet_ids
  db_username         = var.db_username
  db_password         = var.db_password
}

module "compute" {
  source = "./modules/compute"

  providers = { aws = aws }

  project_name       = var.project_name
  vpc_id             = module.networking.vpc_id
  private_subnet_ids = module.networking.private_subnet_ids
  db_address         = module.database.db_address
  db_port            = module.database.db_port
  db_name            = module.database.db_name
  db_username        = var.db_username
  db_password        = var.db_password
}

module "load_balancer" {
  source = "./modules/load-balancer"

  providers = { aws = aws }

  project_name           = var.project_name
  vpc_id                 = module.networking.vpc_id
  public_subnet_ids      = module.networking.public_subnet_ids
  app_security_group_id  = module.compute.app_security_group_id
  db_security_group_id   = module.database.security_group_id
  autoscaling_group_name = module.compute.autoscaling_group_name
}

module "github_cicd" {
  source = "./modules/github-cicd"

  providers = { aws = aws }

  project_name          = var.project_name
  github_repo           = var.github_repo
  autoscaling_group_arn  = module.compute.autoscaling_group_arn
}
