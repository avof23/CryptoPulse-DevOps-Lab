#--------------------------------------------------------------------
# Terraform module
# Provision:
#  - VPC
#  - Internet Gateway
#  - XX Public Subnets
#  - XX Private Subnets
#  - XX DB Subnets
#  - XX NAT Gateways in Public to give access to Internet from Private Sunbets
# Made by A. Vlashchenkov, 07.2026
#--------------------------------------------------------------------

#-----DATA Definition------------------------------------------------
data "aws_availability_zones" "av_zones" {}

#-----VPC and IGW----------------------------------------------------
resource "aws_vpc" "env_vpc" {
  cidr_block = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "${var.env}-vpc"
  }
}

resource "aws_internet_gateway" "igw" {
    vpc_id = aws_vpc.env_vpc.id
    tags = {
      Name = "${var.env}-igw"
  }
}

#-----Public Subnets and Route tables--------------------------------
resource "aws_subnet" "public_subnets" {
  count = length(var.public_subnet_cidrs)
  vpc_id = aws_vpc.env_vpc.id
  cidr_block = element(var.public_subnet_cidrs, count.index)
  availability_zone = data.aws_availability_zones.av_zones.names[count.index]
  tags = {
    Name = "${var.env}-public-${count.index + 1}"
  }
}

resource "aws_route_table" "route_public" {
  vpc_id         = aws_vpc.env_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    Name = "${var.env}-route-public"
  }
}

resource "aws_route_table_association" "public_routes" {
  count = length(aws_subnet.public_subnets)
  route_table_id = aws_route_table.route_public.id
  subnet_id = aws_subnet.public_subnets[count.index].id
}

//-----EIP and NAT---------------------------------------------------
resource "aws_eip" "ip_addresses" {
  count = length(var.private_subnet_cidrs)
  domain = "vpc"
  tags = {
    Name = "${var.env}-eip-nat-gw-${count.index + 1}"
  }
}

resource "aws_nat_gateway" "nats" {
  count = length(var.private_subnet_cidrs)
  allocation_id = aws_eip.ip_addresses[count.index].id
  subnet_id     = element(aws_subnet.public_subnets[*].id, count.index)
  tags = {
    Name = "${var.env}-nat-gw-${count.index + 1}"
  }
}

//-----Private Subnets and Route table-------------------------------
resource "aws_subnet" "private_subnets" {
  count = length(var.private_subnet_cidrs)
  vpc_id = aws_vpc.env_vpc.id
  cidr_block = element(var.private_subnet_cidrs, count.index)
  availability_zone = data.aws_availability_zones.av_zones.names[count.index]
  tags = {
    Name = "${var.env}-private-${count.index + 1}"
  }
}

resource "aws_route_table" "route_private" {
  count = length(var.private_subnet_cidrs)
  vpc_id         = aws_vpc.env_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nats[count.index].id
  }
  tags = {
    Name = "${var.env}-route-private-${count.index + 1}"
  }
}

resource "aws_route_table_association" "private_routes" {
  count = length(aws_subnet.private_subnets)
  route_table_id = aws_route_table.route_private[count.index].id
  subnet_id = aws_subnet.private_subnets[count.index].id
}

//-----DB Subnets and Route table------------------------------------
resource "aws_subnet" "db_subnets" {
  count = length(var.db_subnet_cidrs)
  vpc_id = aws_vpc.env_vpc.id
  cidr_block = element(var.db_subnet_cidrs, count.index)
  availability_zone = data.aws_availability_zones.av_zones.names[count.index]
  tags = {
    Name = "${var.env}-db-${count.index + 1}"
  }
}