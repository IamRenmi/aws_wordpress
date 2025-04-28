# Define S3 Bucket for Static Assets

resource "aws_s3_bucket" "static_assets" {
  bucket = var.s3_bucket_name
  acl    = "private" # Start with private, configure access via CloudFront OAI

  tags = {
    Name = "wordpress-static-assets-bucket"
  }
}

# Optional: Configure S3 bucket policy for CloudFront OAI access
# This requires creating a CloudFront Origin Access Identity (OAI) first.
# See cloudfront.tf for OAI creation.

# resource "aws_s3_bucket_policy" "static_assets_policy" {
#   bucket = aws_s3_bucket.static_assets.id
#   policy = jsonencode({
#     Version = "2012-10-17",
#     Statement = [
#       {
#         Effect = "Allow",
#         Principal = {
#           AWS = "arn:aws:iam::cloudfront:user/CloudFront Origin Access Identity ${aws_cloudfront_origin_access_identity.s3_oai.id}" # Use the OAI ARN
#         },
#         Action = "s3:GetObject",
#         Resource = "${aws_s3_bucket.static_assets.arn}/*"
#       }
#     ]
#   })
# }

