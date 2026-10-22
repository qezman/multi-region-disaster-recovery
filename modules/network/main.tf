# Isolated network for this environment. All other resources attach here.
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr

  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project}-${var.environment}-vpc"
  }
}

# Attaches the VPC to the public internet so public subnets can send and receive traffic
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project}-${var.environment}-igw"
  }
}

# One public subnet per AZ. Hosts that need inbound/outbound internet live here
resource "aws_subnet" "public" {
  for_each = toset(var.availability_zones)

  vpc_id            = aws_vpc.main.id
  availability_zone = each.key

  # uses the index of the current AZ in the original list so CIDRs stay stable
  cidr_block = cidrsubnet(var.vpc_cidr, 8, index(var.availability_zones, each.key))

  # resources are reachable from internet
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project}-${var.environment}-public-${each.key}"
  }
}

# One private subnet per AZ for databases. Offset by 10 so CIDRs never overlap public ranges
resource "aws_subnet" "db" {
  for_each = toset(var.availability_zones)

  vpc_id            = aws_vpc.main.id
  availability_zone = each.key

  cidr_block = cidrsubnet(var.vpc_cidr, 8, index(var.availability_zones, each.key) + 10)

  tags = {
    Name = "${var.project}-${var.environment}-db-${each.key}"
  }
}

# Groups the private subnets so RDS can be placed across AZs.
resource "aws_db_subnet_group" "db" {
  name       = "${var.project}-${var.environment}-db"
  subnet_ids = [for s in aws_subnet.db : s.id]

  tags = {
    Name = "${var.project}-${var.environment}-db"
  }
}

# Routes for public subnets (internet-facing traffic)
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
  cidr_block = "0.0.0.0/0"
  gateway_id = aws_internet_gateway.main.id
}

  tags = {
    Name = "${var.project}-${var.environment}-public-rt"
  }
}

# routes for database subnets (no public internet path)
resource "aws_route_table" "db" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project}-${var.environment}-db-rt"
  }
}

# binds each public subnet to the public route table
resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# binds each database subnet to the private route table
resource "aws_route_table_association" "db" {
  for_each = aws_subnet.db

  subnet_id      = each.value.id
  route_table_id = aws_route_table.db.id
}
