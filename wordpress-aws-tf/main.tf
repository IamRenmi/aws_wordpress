# Configure the AWS Provider
provider "aws" {
  region = var.aws_region
}

# Data source to get the availability zones for the selected region
data "aws_availability_zones" "available" {
  state = "available"
}
