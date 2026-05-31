locals {
  bucket_name = "bedrock-assets-${var.student_id}"
}

# ── S3 Assets Bucket ──────────────────────────────────────────────────────────
resource "aws_s3_bucket" "assets" {
  bucket = local.bucket_name
  tags   = { Name = local.bucket_name }
}

resource "aws_s3_bucket_versioning" "assets" {
  bucket = aws_s3_bucket.assets.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "assets" {
  bucket                  = aws_s3_bucket.assets.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "assets" {
  bucket = aws_s3_bucket.assets.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Bucket policy: bedrock-dev-view PutObject + Lambda GetObject + enforce SSL
resource "aws_s3_bucket_policy" "assets" {
  bucket = aws_s3_bucket.assets.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowDevViewPutObject"
        Effect = "Allow"
        Principal = { AWS = var.bedrock_dev_view_arn }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.assets.arn}/*"
      },
      {
        Sid    = "AllowLambdaGetObject"
        Effect = "Allow"
        Principal = { AWS = var.lambda_role_arn }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.assets.arn}/*"
      },
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.assets]
}

# ── Lambda Function ───────────────────────────────────────────────────────────
data "archive_file" "lambda" {
  type        = "zip"
  source_file = "${path.root}/../lambda/bedrock_asset_processor/handler.py"
  output_path = "${path.module}/lambda.zip"
}

resource "aws_lambda_function" "asset_processor" {
  filename         = data.archive_file.lambda.output_path
  function_name    = "bedrock-asset-processor"
  role             = var.lambda_role_arn
  handler          = "handler.handler"
  runtime          = "python3.12"
  source_code_hash = data.archive_file.lambda.output_base64sha256

  tags = { Name = "bedrock-asset-processor" }
}

# ── Lambda Permission (allow S3 to invoke) ────────────────────────────────────
resource "aws_lambda_permission" "s3_invoke" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.asset_processor.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.assets.arn
}

# ── S3 Event Notification ─────────────────────────────────────────────────────
resource "aws_s3_bucket_notification" "assets" {
  bucket = aws_s3_bucket.assets.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.asset_processor.arn
    events              = ["s3:ObjectCreated:*"]
  }

  depends_on = [aws_lambda_permission.s3_invoke]
}
