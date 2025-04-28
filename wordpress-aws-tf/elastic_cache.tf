# Define ElastiCache Memcached Cluster

# Create an ElastiCache Subnet Group (must span at least 2 Availability Zones)
resource "aws_elasticache_subnet_group" "main" {
  name       = "wordpress-elasticache-subnet-group"
  # Use the private data subnets for the cache
  subnet_ids = aws_subnet.private_data[*].id

  tags = {
    Name = "wordpress-elasticache-subnet-group"
  }
}

# Create the ElastiCache Memcached Cluster
resource "aws_elasticache_cluster" "main" {
  cluster_id           = var.elasticache_cluster_id
  engine               = "memcached"
  node_type            = var.elasticache_node_type
  num_cache_nodes      = var.elasticache_num_nodes
  parameter_group_name = "default.memcached1.6" # Choose appropriate parameter group
  port                 = 11211 # Default Memcached port
  subnet_group_name    = aws_elasticache_subnet_group.main.name
  security_group_ids   = [aws_security_group.elasticache.id] # Associate with ElastiCache security group

  tags = {
    Name = "wordpress-elasticache-cluster"
  }
}

