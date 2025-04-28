# Define EFS File System and Mount Targets

# Create the EFS File System
resource "aws_efs_file_system" "main" {
  creation_token = var.efs_name # Unique identifier
  encrypted      = true # Enable encryption at rest

  # Optional: Configure performance mode, throughput mode, lifecycle policies
  # performance_mode = "generalPurpose"
  # throughput_mode  = "bursting"
  # lifecycle_policy {
  #   transition_to_ia = "AFTER_30_DAYS"
  # }

  tags = {
    Name = var.efs_name
  }
}

# Create EFS Mount Targets in private subnets (both app and data, as needed)
# It's common to mount EFS in the same subnets where instances need access.
# We'll create mount targets in both private app and private data subnets
# to allow flexibility, though WordPress instances are in private app subnets.
resource "aws_efs_mount_target" "app_subnets" {
  count           = length(aws_subnet.private_app)
  file_system_id  = aws_efs_file_system.main.id
  subnet_id       = aws_subnet.private_app[count.index].id
  security_groups = [aws_security_group.efs.id] # Associate with EFS security group

}

resource "aws_efs_mount_target" "data_subnets" {
  count           = length(aws_subnet.private_data)
  file_system_id  = aws_efs_file_system.main.id
  subnet_id       = aws_subnet.private_data[count.index].id
  security_groups = [aws_security_group.efs.id] # Associate with EFS security group

}

