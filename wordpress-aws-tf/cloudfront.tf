# Define CloudFront Distribution

# Create a CloudFront Origin Access Identity (OAI) for S3
# This allows CloudFront to access private S3 content
resource "aws_cloudfront_origin_access_identity" "s3_oai" {
  comment = "OAI for S3 static assets bucket"
}


resource "aws_cloudfront_distribution" "main" {
  origin {
    domain_name = aws_lb.main.dns_name # ALB as the primary origin
    origin_id   = "alb-origin"

    # Optional: Configure custom headers, timeouts etc.
    # custom_origin_config {
    #   http_port              = 80
    #   https_port             = 443
    #   origin_protocol_policy = "match-viewer" # Or "https-only"
    #   origin_ssl_protocols   = ["TLSv1.2"]
    # }
  }

  origin {
    domain_name = aws_s3_bucket.static_assets.bucket_regional_domain_name # S3 bucket as a secondary origin for static assets
    origin_id   = "s3-static-assets"
    # Use the OAI for S3 origin access
    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.s3_oai.cloudfront_access_identity_path
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "CloudFront distribution for WordPress"
  default_root_object = "index.php" # Or index.html if you have one

  # Default cache behavior for dynamic content (ALB origin)
  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "alb-origin"

    # Configure forwarding based on your needs (cookies, headers, query strings)
    # For WordPress, you often need to forward cookies and query strings
    forwarded_values {
      query_string = true
      cookies {
        forward = "all" # Or "none", or "whitelist" specific cookies
      }
      headers = ["Origin", "Authorization"] # Example headers to forward
    }

    viewer_protocol_policy = "redirect-to-https" # Redirect HTTP to HTTPS
    min_ttl                = 0 # Minimum TTL (seconds)
    default_ttl            = 3600 # Default TTL (seconds)
    max_ttl                = 86400 # Maximum TTL (seconds)

    # Optional: Configure Lambda@Edge or CloudFront Functions
    # lambda_function_associations {
    #   event_type   = "viewer-request"
    #   lambda_arn = "arn:aws:lambda:us-east-1:YOUR_ACCOUNT_ID:function:YOUR_LAMBDA_FUNCTION_NAME:YOUR_VERSION"
    # }
  }

  # Cache behavior for static assets (S3 origin)
  ordered_cache_behavior {
    path_pattern           = "/wp-content/uploads/*" # Example path pattern for uploads
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "s3-static-assets"

    forwarded_values {
      query_string = false # Typically no query strings for static assets
      cookies {
        forward = "none" # No cookies needed for static assets
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 86400 # Cache static assets longer
    max_ttl                = 31536000 # Cache static assets much longer

    # Optional: Configure Lambda@Edge or CloudFront Functions
  }

    ordered_cache_behavior {
    path_pattern           = "/wp-content/themes/*/assets/*" # Example path pattern for theme assets
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "s3-static-assets"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 86400
    max_ttl                = 31536000
  }

      ordered_cache_behavior {
    path_pattern           = "/wp-content/plugins/*/assets/*" # Example path pattern for plugin assets
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "s3-static-assets"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 86400
    max_ttl                = 31536000
  }


  # Configure custom error responses (optional)
  # custom_error_response {
  #   error_code          = 404
  #   response_page_path  = "/404.html"
  #   response_code       = 404
  #   error_caching_min_ttl = 300
  # }

  # Configure logging (recommended)
  # logging_config {
  #   include_cookies = false
  #   bucket          = "your-cloudfront-logs-bucket.s3.amazonaws.com" # **UPDATE THIS**
  #   prefix          = "cloudfront-logs/"
  # }

  # Configure price class
  price_class = var.cloudfront_price_class

  # Configure restrictions (mandatory block)
  restrictions {
    geo_restriction {
      restriction_type = "none" # Set to "none" to allow access from all countries
      # If you want to restrict, change to "whitelist" or "blacklist"
      # and provide a list of "locations" (country codes)
      # locations = ["US", "CA", "GB"] # Example for whitelist
    }
  }

  # Configure viewer certificate (SSL/TLS)
  viewer_certificate {
    # Use the ACM certificate associated with your domain
    acm_certificate_arn      = "arn:aws:acm:us-east-1:YOUR_ACCOUNT_ID:certificate/YOUR_CERTIFICATE_ID" # **UPDATE THIS** - Must be in us-east-1
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021" # Choose a secure minimum protocol
  }

  # Associate with your domain names (CNAMEs)
  # Combine the base domain and www subdomain conditionally into a single list
  aliases = var.create_www_record ? [var.domain_name, "www.${var.domain_name}"] : [var.domain_name]


  tags = {
    Name = "wordpress-cloudfront-distribution"
  }
}
