# Define Security Groups and their Rules

# --- Define Security Groups (without ingress/egress rules initially) ---

# Security Group for the Application Load Balancer
resource "aws_security_group" "alb" {
  name        = "wordpress-alb-sg"
  description = "Security group for ALB"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "wordpress-alb-sg"
  }
}

# Security Group for WordPress Instances (behind ALB)
resource "aws_security_group" "wordpress" {
  name        = "wordpress-instance-sg"
  description = "Security group for WordPress instances"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "wordpress-instance-sg"
  }
}

# Security Group for RDS Database
resource "aws_security_group" "rds" {
  name        = "wordpress-rds-sg"
  description = "Security group for RDS database"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "wordpress-rds-sg"
  }
}

# Security Group for ElastiCache Memcached
resource "aws_security_group" "elasticache" {
  name        = "wordpress-elasticache-sg"
  description = "Security group for ElastiCache Memcached"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "wordpress-elasticache-sg"
  }
}

# Security Group for EFS Mount Targets
resource "aws_security_group" "efs" {
  name        = "wordpress-efs-sg"
  description = "Security group for EFS mount targets"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "wordpress-efs-sg"
  }
}

# Security Group for Bastion Host (Optional)
resource "aws_security_group" "bastion" {
  count       = var.create_bastion_host ? 1 : 0
  name        = "wordpress-bastion-sg"
  description = "Security group for Bastion host"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "wordpress-bastion-sg"
  }
}

# --- Define Security Group Rules ---

# ALB Ingress Rules (Allow HTTP/HTTPS from anywhere)
resource "aws_security_group_rule" "alb_ingress_http" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.alb.id
  description       = "Allow HTTP from anywhere"
}

resource "aws_security_group_rule" "alb_ingress_https" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.alb.id
  description       = "Allow HTTPS from anywhere"
}

# ALB Egress Rule (Allow all outbound)
resource "aws_security_group_rule" "alb_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.alb.id
  description       = "Allow all outbound traffic"
}

# WordPress Instance Ingress Rules (Allow HTTP/HTTPS from ALB SG)
resource "aws_security_group_rule" "wordpress_ingress_alb_http" {
  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb.id
  security_group_id        = aws_security_group.wordpress.id
  description              = "Allow HTTP from ALB SG"
}

resource "aws_security_group_rule" "wordpress_ingress_alb_https" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb.id
  security_group_id        = aws_security_group.wordpress.id
  description              = "Allow HTTPS from ALB SG"
}

# WordPress Instance Egress Rules (Allow outbound to RDS, ElastiCache, EFS, Internet)
resource "aws_security_group_rule" "wordpress_egress_rds" {
  type                     = "egress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  destination_security_group_id = aws_security_group.rds.id
  security_group_id        = aws_security_group.wordpress.id
  description              = "Allow outbound to RDS SG"
}

resource "aws_security_group_rule" "wordpress_egress_elasticache" {
  type                     = "egress"
  from_port                = 11211 # Default Memcached port
  to_port                  = 11211
  protocol                 = "tcp"
  destination_security_group_id = aws_security_group.elasticache.id
  security_group_id        = aws_security_group.wordpress.id
  description              = "Allow outbound to ElastiCache SG"
}

resource "aws_security_group_rule" "wordpress_egress_efs" {
  type                     = "egress"
  from_port                = 2049 # NFS port
  to_port                  = 2049
  protocol                 = "tcp"
  destination_security_group_id = aws_security_group.efs.id
  security_group_id        = aws_security_group.wordpress.id
  description              = "Allow outbound to EFS SG"
}

# Allow outbound traffic to the NAT Gateway (for internet access for updates, etc.)
# This rule is often implicitly handled by the route table, but explicitly allowing
# outbound traffic to all destinations is common for application instances.
resource "aws_security_group_rule" "wordpress_egress_internet" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.wordpress.id
  description       = "Allow all outbound traffic to internet via NAT Gateway"
}


# RDS Ingress Rule (Allow MySQL/MariaDB from WordPress SG)
resource "aws_security_group_rule" "rds_ingress_wordpress" {
  type                     = "ingress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.wordpress.id
  security_group_id        = aws_security_group.rds.id
  description              = "Allow MySQL/MariaDB from WordPress SG"
}

# RDS Egress Rule (Allow all outbound - typically not needed unless connecting to external services)
resource "aws_security_group_rule" "rds_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.rds.id
  description       = "Allow all outbound traffic"
}


# ElastiCache Ingress Rule (Allow Memcached from WordPress SG)
resource "aws_security_group_rule" "elasticache_ingress_wordpress" {
  type                     = "ingress"
  from_port                = 11211 # Default Memcached port
  to_port                  = 11211
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.wordpress.id
  security_group_id        = aws_security_group.elasticache.id
  description              = "Allow Memcached from WordPress SG"
}

# ElastiCache Egress Rule (Allow all outbound - typically not needed)
resource "aws_security_group_rule" "elasticache_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.elasticache.id
  description       = "Allow all outbound traffic"
}


# EFS Ingress Rule (Allow NFS from WordPress SG)
resource "aws_security_group_rule" "efs_ingress_wordpress" {
  type                     = "ingress"
  from_port                = 2049 # NFS port
  to_port                  = 2049
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.wordpress.id
  security_group_id        = aws_security_group.efs.id
  description              = "Allow NFS from WordPress SG"
}

# EFS Egress Rule (Allow all outbound - typically not needed)
resource "aws_security_group_rule" "efs_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.efs.id
  description       = "Allow all outbound traffic"
}


# Bastion Host Ingress Rule (Allow SSH from allowed_ssh_cidr)
resource "aws_security_group_rule" "bastion_ingress_ssh" {
  count             = var.create_bastion_host ? 1 : 0
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = var.allowed_ssh_cidr # **IMPORTANT: Change this variable to your IP**
  security_group_id = aws_security_group.bastion[0].id
  description       = "Allow SSH from allowed_ssh_cidr"
}

# Bastion Host Egress Rule (Allow outbound SSH to WordPress SG)
resource "aws_security_group_rule" "bastion_egress_wordpress_ssh" {
  count                        = var.create_bastion_host ? 1 : 0
  type                         = "egress"
  from_port                    = 22
  to_port                      = 22
  protocol                     = "tcp"
  destination_security_group_id = aws_security_group.wordpress.id
  security_group_id            = aws_security_group.bastion[0].id
  description                  = "Allow outbound SSH to WordPress SG"
}

# Bastion Host Egress Rule (Allow outbound SSH to RDS SG - optional)
 resource "aws_security_group_rule" "bastion_egress_rds_ssh" {
   count                         = var.create_bastion_host ? 1 : 0
   type                          = "egress"
   from_port                     = 3306
   to_port                       = 3306
   protocol                      = "tcp"
   destination_security_group_id = aws_security_group.rds.id
   security_group_id             = aws_security_group.bastion[0].id
   description                   = "Allow outbound SSH to RDS SG (optional)"
 }


# Bastion Host Egress Rule (Allow all outbound - optional, often limited for bastion)
resource "aws_security_group_rule" "bastion_egress_all" {
  count             = var.create_bastion_host ? 1 : 0
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.bastion[0].id
  description       = "Allow all outbound traffic"
}
