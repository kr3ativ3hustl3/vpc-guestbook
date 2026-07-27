##############################################################################
# NETWORKING MODULE
#
# Creates: a VPC with three subnet tiers (public, private/app, and an
# isolated database tier) across two Availability Zones, an Internet
# Gateway, a single NAT Gateway, and the route tables connecting it
# all together.
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
# VPC + Internet Gateway
##############################################################################

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name    = "${var.project_name}-vpc"
    Project = var.project_name
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name    = "${var.project_name}-igw"
    Project = var.project_name
  }
}

##############################################################################
# Subnets — one of each tier per Availability Zone
##############################################################################

resource "aws_subnet" "public" {
  count                   = length(var.availability_zones)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name    = "${var.project_name}-public-${var.availability_zones[count.index]}"
    Project = var.project_name
    Tier    = "public"
  }
}

resource "aws_subnet" "private" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name    = "${var.project_name}-private-${var.availability_zones[count.index]}"
    Project = var.project_name
    Tier    = "private"
  }
}

resource "aws_subnet" "database" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.db_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name    = "${var.project_name}-db-${var.availability_zones[count.index]}"
    Project = var.project_name
    Tier    = "database"
  }
}

##############################################################################
# NAT Gateway — deliberately ONE, not one per AZ.
#
# A NAT Gateway per AZ is the textbook highly-available answer, but
# each one bills separately (~$32/mo each). For a portfolio project
# that isn't serving real production traffic, running a single NAT
# Gateway in one AZ is a reasonable, explainable cost tradeoff: if
# that AZ's NAT Gateway has an issue, the private-subnet instances in
# the OTHER AZ temporarily lose outbound internet access, but nothing
# about their inbound availability (via the ALB) is affected. Worth
# being able to explain this tradeoff explicitly if asked.
##############################################################################

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name    = "${var.project_name}-nat-eip"
    Project = var.project_name
  }
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  tags = {
    Name    = "${var.project_name}-nat"
    Project = var.project_name
  }

  depends_on = [aws_internet_gateway.main]
}

##############################################################################
# Route tables
##############################################################################

# Public: routes everything to the Internet Gateway.
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name    = "${var.project_name}-public-rt"
    Project = var.project_name
  }
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Private (app tier): routes outbound traffic through the NAT Gateway
# — needed so instances can reach the internet for OS updates, package
# installs, etc., without being directly reachable FROM the internet.
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name    = "${var.project_name}-private-rt"
    Project = var.project_name
  }
}

resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# Database: deliberately NO route to the internet at all — not even
# via NAT. Only the implicit "local" route (automatic in every VPC
# route table) exists, meaning traffic can only reach other resources
# inside this VPC. A database that never needs to call out to the
# internet shouldn't have a path to it.
resource "aws_route_table" "database" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name    = "${var.project_name}-db-rt"
    Project = var.project_name
  }
}

resource "aws_route_table_association" "database" {
  count          = length(aws_subnet.database)
  subnet_id      = aws_subnet.database[count.index].id
  route_table_id = aws_route_table.database.id
}
