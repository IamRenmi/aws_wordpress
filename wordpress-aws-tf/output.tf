# Define Output Variables

# Output the ALB DNS Name
output "alb_dns_name" {
  description = "The DNS name of the Application Load Balancer."
  value       = aws_lb.main.dns_name
}

# Output the CloudFront Distribution Domain Name
output "cloudfront_domain_name" {
  description = "The domain name of the CloudFront distribution."
  value       = aws_cloudfront_distribution.main.domain_name
}

# Output the Bastion Host Public IP (if created)
output "bastion_public_ip" {
  description = "The public IP address of the Bastion host (if created)."
  value       = var.create_bastion_host ? aws_instance.bastion[0].public_ip : "Bastion host not created."
}

# Output the RDS Endpoint
output "rds_endpoint" {
  description = "The endpoint address of the RDS database instance."
  value       = aws_db_instance.main.address
}

# Output the ElastiCache Configuration Endpoint
output "elasticache_configuration_endpoint" {
  description = "The configuration endpoint of the ElastiCache Memcached cluster."
  value       = aws_elasticache_cluster.main.configuration_endpoint
}

# Output the EFS File System ID
output "efs_file_system_id" {
  description = "The ID of the EFS file system."
  value       = aws_efs_file_system.main.id
}

