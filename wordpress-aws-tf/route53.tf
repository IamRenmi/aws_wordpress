# Define Route 53 Records

# Data source to get the Hosted Zone ID for your domain
# Assumes you have a public hosted zone for var.domain_name
data "aws_route53_zone" "main" {
  name = var.domain_name
}

# Create an Alias record for the root domain (@) pointing to the CloudFront distribution
resource "aws_route53_record" "root_domain" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.main.domain_name
    zone_id                = aws_cloudfront_distribution.main.hosted_zone_id
    evaluate_target_health = false # CloudFront health is managed by its origins
  }
}

# Create an Alias record for the 'www' subdomain pointing to the CloudFront distribution (if enabled)
resource "aws_route53_record" "www_subdomain" {
  count   = var.create_www_record ? 1 : 0
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "www.${var.domain_name}"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.main.domain_name
    zone_id                = aws_cloudfront_distribution.main.hosted_zone_id
    evaluate_target_health = false
  }
}

# Optional: Create an A record for the Bastion host (if created)
resource "aws_route53_record" "bastion" {
  count   = var.create_bastion_host ? 1 : 0
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "bastion.${var.domain_name}" # Example subdomain for bastion
  type    = "A"
  ttl     = 300
  records = [aws_instance.bastion[0].public_ip] # Use the public IP of the bastion host
}

