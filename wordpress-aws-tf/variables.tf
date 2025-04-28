# Define input variables for the Terraform configuration

# AWS Region
variable "aws_region" {
  description = "The AWS region to deploy resources into."
  type        = string
  default     = "us-east-1" # Example region, change as needed
}

# VPC Configuration
variable "vpc_cidr" {
  description = "The CIDR block for the VPC."
  type        = string
  default     = "48.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "A list of CIDR blocks for the public subnets (must be within VPC CIDR)."
  type        = list(string)
  default     = ["48.0.1.0/24", "48.0.2.0/24"] # Example CIDRs, adjust based on AZs
}

variable "private_app_subnet_cidrs" {
  description = "A list of CIDR blocks for the private application subnets (must be within VPC CIDR)."
  type        = list(string)
  default     = ["48.0.11.0/24", "48.0.12.0/24"] # Example CIDRs, adjust based on AZs
}

variable "private_data_subnet_cidrs" {
  description = "A list of CIDR blocks for the private data subnets (must be within VPC CIDR)."
  type        = list(string)
  default     = ["48.0.21.0/24", "48.0.22.0/24"] # Example CIDRs, adjust based on AZs
}

# Instance Configuration
variable "instance_type" {
  description = "The EC2 instance type for WordPress instances and Bastion host."
  type        = string
  default     = "t2.micro" # Choose an appropriate instance type
}

variable "ami_id" {
  description = "The ID of the AMI to use for EC2 instances (e.g., Amazon Linux 2 or 2023)."
  type        = string
  # Find a suitable AMI ID for your region and OS (e.g., Amazon Linux 2 or 2023)
  # Example for eu-central-1, Amazon Linux 2 (HVM), SSD Volume Type
  # You should look up the latest AMI ID for your chosen region and OS
  default     = "ami-0e449927258d45bc4" # Example AMI ID, **UPDATE THIS**
}

variable "key_pair_name" {
  description = "The name of the EC2 Key Pair to allow SSH access to instances (especially Bastion)."
  type        = string
  default     = "bastion"
  # You must have this key pair already created in your AWS account
}

# Database Configuration (RDS)
variable "db_instance_identifier" {
  description = "The identifier for the RDS DB instance."
  type        = string
  default     = "wordpress-db"
}

variable "db_engine" {
  description = "The database engine for RDS (e.g., mysql, mariadb)."
  type        = string
  default     = "mysql"
}

variable "db_engine_version" {
  description = "The version of the database engine."
  type        = string
  default     = "8.0.40" # Specify a supported version
}

variable "db_instance_class" {
  description = "The instance class for the RDS DB instance."
  type        = string
  default     = "db.t3.micro" # Choose an appropriate instance class
}

variable "db_allocated_storage" {
  description = "The allocated storage in GiB for the RDS DB instance."
  type        = number
  default     = 20
}

variable "db_name" {
  description = "The name of the database to create in the RDS instance for WordPress."
  type        = string
  default     = "wordpress"
}

variable "db_username" {
  description = "The master username for the RDS DB instance."
  type        = string
  default     = "admin"
}

# IMPORTANT: Using a variable for the master password is NOT recommended for production.
# Use AWS Secrets Manager or Parameter Store instead.
variable "db_password" {
  description = "The master password for the RDS DB instance. Use Secrets Manager in production."
  type        = string
  sensitive   = true # Mark as sensitive to prevent logging
  default     = "lab-password"
}

# ElastiCache Configuration
variable "elasticache_cluster_id" {
  description = "The ID for the ElastiCache Memcached cluster."
  type        = string
  default     = "wordpress-cache"
}

variable "elasticache_node_type" {
  description = "The node type for the ElastiCache cluster."
  type        = string
  default     = "cache.t3.micro" # Choose an appropriate node type
}

variable "elasticache_num_nodes" {
  description = "The number of nodes in the ElastiCache cluster (including master and replicas)."
  type        = number
  default     = 2 # 1 Master + 1 Replica minimum for high availability

  validation {
    condition     = var.elasticache_num_nodes >= 1
    error_message = "The number of ElastiCache nodes must be at least 1."
  }
}

# EFS Configuration
variable "efs_name" {
  description = "The name for the EFS filesystem."
  type        = string
  default     = "wordpress-efs"
}

# Route 53 Configuration
variable "domain_name" {
  description = "The domain name managed in Route 53 (e.g., yourwebsite.com)."
  type        = string
  default     = "renmi-li.com"# You must have a Hosted Zone for this domain in Route 53
}

variable "create_www_record" {
  description = "Whether to create a www. record pointing to the CloudFront distribution."
  type        = bool
  default     = true
}

# CloudFront Configuration
variable "cloudfront_price_class" {
  description = "The price class for the CloudFront distribution."
  type        = string
  default     = "PriceClass_100" # Options: PriceClass_100, PriceClass_200, PriceClass_All
}

# S3 Configuration
variable "s3_bucket_name" {
  description = "The name for the S3 bucket for static assets."
  type        = string
  default     = "renmi-bucket-wp" # Bucket names must be globally unique
}

# User Data Script Configuration
# IMPORTANT: Hardcoding sensitive data in User Data is NOT recommended for production.
# Use AWS Secrets Manager or Parameter Store instead.
variable "wordpress_db_name" {
  description = "The database name WordPress will use (should match db_name unless you create a separate user/db)."
  type        = string
  default     = "wordpress" # Should match var.db_name if using the same DB
}

variable "wordpress_db_user" {
  description = "The database username WordPress will use."
  type        = string
  default     = "wp_user" # Create this user using the RDS master user
}

variable "wordpress_db_password" {
  description = "The database password WordPress will use. Use Secrets Manager in production."
  type        = string
  sensitive   = true # Mark as sensitive
  default     = "lab-password"
}

# Optional: Bastion Host Configuration
variable "create_bastion_host" {
  description = "Whether to create a Bastion host."
  type        = bool
  default     = true
}

variable "allowed_ssh_cidr" {
  description = "The CIDR block allowed to SSH into the Bastion host."
  type        = list(string)
  # **IMPORTANT**: Restrict this to your specific IP range for security!
  default     = ["0.0.0.0/0"] # **CHANGE THIS TO YOUR PUBLIC IP CIDR**
}

