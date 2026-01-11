
# ----------------------
# S3 Bucket
# ----------------------

resource "aws_s3_bucket" "etl_bucket" {
  depends_on = [aws_nat_gateway.nat]
  bucket     = "facebook-etl-bucket-${random_id.bucket_suffix.hex}"

  # Modern best practice: disable ACLs and enforce ownership
  #object_ownership = "BucketOwnerEnforced"

  tags = {
    Name        = "facebook-etl-bucket"
    Environment = "dev"
  }

  force_destroy = true # allows deletion even if objects exist
}

# Random suffix for unique bucket name
resource "random_id" "bucket_suffix" {
  byte_length = 4
}


# ----------------------
# Lambda S3 IAM Policy
# ----------------------
resource "aws_iam_policy" "lambda_s3_policy" {
  name        = "lambda-s3-access"
  description = "Allow Lambda to read/write S3 bucket"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.etl_bucket.arn,
          "${aws_s3_bucket.etl_bucket.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_s3_attach" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = aws_iam_policy.lambda_s3_policy.arn
}
