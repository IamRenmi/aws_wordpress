# Define RDS Database

# Create a DB Subnet Group for RDS (must span at least 2 Availability Zones)
resource "aws_db_subnet_group" "main" {
  name       = "wordpress-rds-subnet-group"
  # Use the private data subnets for the database
  subnet_ids = aws_subnet.private_data[*].id

  tags = {
    Name = "wordpress-rds-subnet-group"
  }
}

# Create the RDS DB Instance
resource "aws_db_instance" "main" {
  identifier              = var.db_instance_identifier
  engine                  = var.db_engine
  engine_version          = var.db_engine_version
  instance_class          = var.db_instance_class
  allocated_storage       = var.db_allocated_storage
  storage_type            = "gp2" # General Purpose SSD
  db_name                 = var.db_name
  username                = var.db_username
  password                = var.db_password # Use sensitive variable
  db_subnet_group_name    = aws_db_subnet_group.main.name
  vpc_security_group_ids  = [aws_security_group.rds.id] # Associate with RDS security group
  skip_final_snapshot     = true # Set to false for production
  multi_az                = true # Enable Multi-AZ for high availability
  publicly_accessible     = false # Database should NOT be publicly accessible

  # Optional: Configure backup retention, maintenance window, etc.
  # backup_retention_period = 7
  # preferred_backup_window = "07:00-09:00"
  # preferred_maintenance_window = "Mon:03:00-Mon:04:00"

  tags = {
    Name = "wordpress-rds-instance"
  }
}

