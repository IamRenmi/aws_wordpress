# Define Auto Scaling Group (ASG) and Launch Template for WordPress Instances

# Data source to get the latest Amazon Linux 2 AMI (or your chosen OS)
# Using a data source makes your AMI selection dynamic
# data "aws_ami" "amazon_linux_2" {
#   most_recent = true
#   owners      = ["amazon"] # Or your account ID if using a custom AMI

#   filter {
#     name   = "name"
#     values = ["amzn2-ami-hvm-*-x86_64-gp2"] # Adjust pattern for your desired AMI
#   }

#   filter {
#     name   = "virtualization-type"
#     values = ["hvm"]
#   }
# }
# Note: Using var.ami_id directly as defined in variables.tf for simplicity,
# but using a data source like the commented-out block is often better practice.


# Define the Launch Template for EC2 instances
resource "aws_launch_template" "wordpress" {
  name_prefix   = "wordpress-lt-"
  image_id      = var.ami_id # Use the variable for AMI ID
  instance_type = var.instance_type
  key_name      = var.key_pair_name # Specify the key pair for SSH access

  network_interfaces {
    # Instances are in private subnets, so they don't get public IPs
    # They inherit the subnet's map_public_ip_on_launch setting (which should be false for private)
    # They need security groups for communication
    security_groups = [aws_security_group.wordpress.id]
    # Associate with a subnet (ASG handles distribution across subnets)
    # This is a template, ASG will assign the actual subnet
  }

  # User Data script read from the userdata.sh file
  # Use the file() function to read the content of the script file
  user_data = base64encode(templatefile("${path.module}/userdata/userdata.sh", {
    # Pass variables from Terraform to the shell script
    wordpress_db_name     = var.wordpress_db_name
    wordpress_db_user     = var.wordpress_db_user
    wordpress_db_password = var.wordpress_db_password # Pass sensitive variable (use Secrets Manager in production)
    rds_endpoint          = aws_db_instance.main.address # Get RDS endpoint from the created RDS instance
    rds_port              = aws_db_instance.main.port   # Get RDS port from the created RDS instance
    db_username           = var.db_username             # Pass RDS master username (use Secrets Manager in production)
    db_password           = var.db_password             # Pass RDS master password (use Secrets Manager in production)
    efs_file_system_id    = aws_efs_file_system.main.id # Get EFS ID from the created EFS filesystem
  }))

  tags = {
    Name = "wordpress-launch-template"
  }
}

# Define the Auto Scaling Group
resource "aws_autoscaling_group" "wordpress" {
  name                      = "wordpress-asg"
  max_size                  = 3 # Maximum number of instances
  min_size                  = 1 # Minimum number of instances
  desired_capacity          = 1 # Initial number of instances
  vpc_zone_identifier       = aws_subnet.private_app[*].id # Launch instances in private app subnets
  target_group_arns         = [aws_lb_target_group.wordpress.arn] # Attach to the ALB target group
  health_check_type         = "ELB" # Use ALB health checks
  health_check_grace_period = 300 # Give instances time to start and pass health checks

  launch_template {
    id      = aws_launch_template.wordpress.id
    version = "$Latest" # Use the latest version of the launch template
  }

  # Optional: Add scaling policies based on CPU utilization, etc.
  # resource "aws_autoscaling_policy" "cpu_scaling" {
  #   name                   = "wordpress-cpu-scaling"
  #   scaling_adjustment     = 1
  #   cooldown               = 300
  #   metric_aggregation_type = "Average"
  #   policy_type            = "StepScaling"
  #   autoscaling_group_name = aws_autoscaling_group.wordpress.name
  #
  #   step_adjustment {
  #     metric_interval_lower_bound = 0
  #     scaling_adjustment          = 1
  #   }
  # }

  # resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  #   alarm_name          = "wordpress-cpu-high"
  #   comparison_operator = "GreaterThanThreshold"
  #   evaluation_periods  = 2
  #   metric_name         = "CPUUtilization"
  #   namespace           = "AWS/EC2"
  #   period              = 60
  #   statistic           = "Average"
  #   threshold           = 70 # Adjust threshold as needed
  #   alarm_description   = "Trigger scaling up when CPU is high"
  #   autoscaling_group_name = aws_autoscaling_group.wordpress.name
  #   dimensions = {
  #     AutoScalingGroupName = aws_autoscaling_group.wordpress.name
  #   }
  #   alarm_actions = [aws_autoscaling_policy.cpu_scaling.arn]
  # }

}
