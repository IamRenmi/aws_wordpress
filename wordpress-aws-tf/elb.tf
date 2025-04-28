# Define Application Load Balancer (ALB)

# Create the ALB
resource "aws_lb" "main" {
  name               = "wordpress-alb"
  internal           = false # Internet-facing
  load_balancer_type = "application"
  # ALB should be in public subnets
  subnets            = aws_subnet.public[*].id
  security_groups    = [aws_security_group.alb.id]

  tags = {
    Name = "wordpress-alb"
  }
  # The healthcheck block was incorrectly placed here.
  # It belongs inside the aws_lb_target_group resource.
}

# Create a Target Group for the ALB
# Traffic is forwarded to instances on port 80 (or 443 if using instance-level SSL)
resource "aws_lb_target_group" "wordpress" {
  name     = "wordpress-tg"
  port     = 80 # Or 443 if instances handle SSL
  protocol = "HTTP" # Or HTTPS if instances handle SSL
  vpc_id   = aws_vpc.main.id

  # Health check configuration for the instances in this target group
  health_check {
    protocol = "HTTP"
    path     = "/" # Or a specific health check path like /healthz
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    interval            = 30
    matcher             = "200-299" # Expect HTTP 2xx response
  }

  tags = {
    Name = "wordpress-tg"
  }
}

# Create an ALB Listener for HTTPS (recommended)
# Requires an ACM certificate in us-east-1 for CloudFront integration
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"
  # You need an ACM certificate ARN here.
  # The certificate must be in us-east-1 if integrating with CloudFront.
  certificate_arn   = "arn:aws:acm:us-east-1:YOUR_ACCOUNT_ID:certificate/YOUR_CERTIFICATE_ID" # **UPDATE THIS**
  ssl_policy        = "ELBSecurityPolicy-2016-08" # Choose an appropriate SSL policy

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.wordpress.arn
  }

  tags = {
    Name = "wordpress-https-listener"
  }
}

# Optional: Create an ALB Listener for HTTP (to redirect to HTTPS)
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301" # Permanent redirect
    }
  }

  tags = {
    Name = "wordpress-http-listener"
  }
}
