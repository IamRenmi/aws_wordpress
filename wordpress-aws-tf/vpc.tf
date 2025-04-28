# Define VPC and Networking Resources

# Create the VPC
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "wordpress-vpc"
  }
}

# Create Public Subnets
resource "aws_subnet" "public" {
  count             = length(var.public_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.public_subnet_cidrs[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true # Public subnets need public IPs

  tags = {
    Name = "wordpress-public-subnet-${count.index + 1}"
  }
}

# Create Private App Subnets
resource "aws_subnet" "private_app" {
  count             = length(var.private_app_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_app_subnet_cidrs[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "wordpress-private-app-subnet-${count.index + 1}"
  }
}

# Create Private Data Subnets
resource "aws_subnet" "private_data" {
  count             = length(var.private_data_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_data_subnet_cidrs[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "wordpress-private-data-subnet-${count.index + 1}"
  }
}

# Create Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "wordpress-igw"
  }
}

# Create NAT Gateways (one per public subnet for high availability)
resource "aws_nat_gateway" "main" {
  count         = length(aws_subnet.public)
  allocation_id = aws_eip.nat[count.index].id # Associate with EIP
  subnet_id     = aws_subnet.public[count.index].id

  tags = {
    Name = "wordpress-natgw-${count.index + 1}"
  }

  # Add depends_on to ensure EIPs are created first
  depends_on = [aws_eip.nat]
}

# Create Elastic IPs for NAT Gateways
resource "aws_eip" "nat" {
  count = length(aws_subnet.public)
  vpc   = true # Associate with VPC

  tags = {
    Name = "wordpress-nat-eip-${count.index + 1}"
  }
}

# Create Public Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id # Route internet traffic via IGW
  }

  tags = {
    Name = "wordpress-public-rt"
  }
}

# Associate Public Route Table with Public Subnets
resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Create Private App Route Table (routes internet traffic via NAT Gateway)
resource "aws_route_table" "private_app" {
  count  = length(aws_subnet.private_app)
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id # Route internet traffic via NAT GW in the same AZ
  }

  tags = {
    Name = "wordpress-private-app-rt-${count.index + 1}"
  }
}

# Associate Private App Route Table with Private App Subnets
resource "aws_route_table_association" "private_app" {
  count          = length(aws_subnet.private_app)
  subnet_id      = aws_subnet.private_app[count.index].id
  route_table_id = aws_route_table.private_app[count.index].id
}

# Create Private Data Route Table (routes internet traffic via NAT Gateway)
# Data subnets also need outbound internet access for updates, etc.
resource "aws_route_table" "private_data" {
  count  = length(aws_subnet.private_data)
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id # Route internet traffic via NAT GW in the same AZ
  }

  tags = {
    Name = "wordpress-private-data-rt-${count.index + 1}"
  }
}

# Associate Private Data Route Table with Private Data Subnets
resource "aws_route_table_association" "private_data" {
  count          = length(aws_subnet.private_data)
  subnet_id      = aws_subnet.private_data[count.index].id
  route_table_id = aws_route_table.private_data[count.index].id
}

