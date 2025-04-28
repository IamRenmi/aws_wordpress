# Define Security Groups

# Security Group for the Application Load Balancer
# Allows inbound HTTP and HTTPS traffic from anywhere
resource "aws_security_group" "alb" {
  name        = "wordpress-alb-sg"
  description = "Allow HTTP/HTTPS traffic to ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Allow HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow HTTPS from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "wordpress-alb-sg"
  }
}

# Security Group for WordPress Instances (behind ALB)
# Allows inbound HTTP/HTTPS traffic ONLY from the ALB security group
# Allows outbound to RDS, ElastiCache, EFS, and NAT Gateway (for internet)
resource "aws_security_group" "wordpress" {
  name        = "wordpress-instance-sg"
  description = "Allow traffic from ALB, and outbound to DB, Cache, EFS"
  vpc_id      = aws_vpc.main.id

  # Allow inbound traffic from the ALB security group
  ingress {
    description     = "Allow HTTP from ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    description     = "Allow HTTPS from ALB"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  # Allow outbound traffic to the RDS security group (MySQL/MariaDB port)
  egress {
    description     = "Allow outbound to RDS"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.rds.id]
  }

  # Allow outbound traffic to the ElastiCache security group (Memcached port)
  egress {
    description     = "Allow outbound to ElastiCache"
    from_port       = 11211 # Default Memcached port
    to_port         = 11211
    protocol        = "tcp"
    security_groups = [aws_security_group.elasticache.id]
  }

  # Allow outbound traffic to the EFS security group (NFS port)
  egress {
    description     = "Allow outbound to EFS"
    from_port       = 2049 # NFS port
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [aws_security_group.efs.id]
  }

  # Allow outbound traffic to the NAT Gateway (for internet access for updates, etc.)
  # This rule is often implicitly handled by the route table, but explicitly allowing
  # outbound traffic to all destinations is common for application instances.
  egress {
    description = "Allow all outbound traffic to internet via NAT Gateway"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }


  tags = {
    Name = "wordpress-instance-sg"
  }
}


# Security Group for RDS Database
# Allows inbound traffic ONLY from the WordPress instance security group
resource "aws_security_group" "rds" {
  name        = "wordpress-rds-sg"
  description = "Allow traffic to RDS from WordPress instances"
  vpc_id      = aws_vpc.main.id

  # Allow inbound traffic from the WordPress instance security group
  ingress {
    description     = "Allow MySQL/MariaDB from WordPress instances"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.wordpress.id]
  }

  # RDS typically doesn't need specific egress rules unless connecting to external services (rare)
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "wordpress-rds-sg"
  }
}

# Security Group for ElastiCache Memcached
# Allows inbound traffic ONLY from the WordPress instance security group
resource "aws_security_group" "elasticache" {
  name        = "wordpress-elasticache-sg"
  description = "Allow traffic to ElastiCache from WordPress instances"
  vpc_id      = aws_vpc.main.id

  # Allow inbound traffic from the WordPress instance security group
  ingress {
    description     = "Allow Memcached from WordPress instances"
    from_port       = 11211 # Default Memcached port
    to_port         = 11211
    protocol        = "tcp"
    security_groups = [aws_security_group.wordpress.id]
  }

  # ElastiCache typically doesn't need specific egress rules
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "wordpress-elasticache-sg"
  }
}

# Security Group for EFS Mount Targets
# Allows inbound NFS traffic from the WordPress instance security group
resource "aws_security_group" "efs" {
  name        = "wordpress-efs-sg"
  description = "Allow NFS traffic to EFS from WordPress instances"
  vpc_id      = aws_vpc.main.id

  # Allow inbound traffic from the WordPress instance security group
  ingress {
    description     = "Allow NFS from WordPress instances"
    from_port       = 2049 # NFS port
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [aws_security_group.wordpress.id]
  }

  # EFS Mount Targets typically don't need specific egress rules
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "wordpress-efs-sg"
  }
}

# Security Group for Bastion Host (Optional)
# Allows inbound SSH traffic from a defined CIDR block
# Allows outbound traffic to private subnets (SSH)
resource "aws_security_group" "bastion" {
  count       = var.create_bastion_host ? 1 : 0
  name        = "wordpress-bastion-sg"
  description = "Allow SSH access to Bastion host"
  vpc_id      = aws_vpc.main.id

  # Allow inbound SSH from specified CIDR block
  ingress {
    description = "Allow SSH from allowed_ssh_cidr"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidr # **IMPORTANT: Change this variable to your IP**
  }

  # Allow outbound SSH to WordPress instances (in private app subnets)
  egress {
    description     = "Allow outbound SSH to WordPress instances"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.wordpress.id]
  }

  # Allow outbound SSH to RDS (optional, for direct DB access from bastion)
   egress {
     description     = "Allow outbound SSH to RDS (optional)"
     from_port       = 3306
     to_port         = 3306
     protocol        = "tcp"
     security_groups = [aws_security_group.rds.id]
   }

  tags = {
    Name = "wordpress-bastion-sg"
  }
}

