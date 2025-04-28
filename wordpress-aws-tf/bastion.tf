# Define Bastion Host (Optional)

resource "aws_instance" "bastion" {
  count         = var.create_bastion_host ? 1 : 0
  ami           = var.ami_id # Use the same AMI as WordPress instances
  instance_type = var.instance_type
  key_name      = var.key_pair_name # Specify the key pair for SSH access
  # Bastion host should be in a public subnet
  subnet_id     = aws_subnet.public[0].id # Place in the first public subnet
  # Bastion needs a public IP to be accessible from the internet
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.bastion[0].id] # Associate with Bastion security group

  tags = {
    Name = "wordpress-bastion-host"
  }
}

