resource "random_string" "suffix" { length = 6 upper = false special = false }

# App bucket
resource "aws_s3_bucket" "app" {
  bucket = "${var.name}-${var.env}-${random_string.suffix.result}"
  tags   = merge(var.tags, { Name = "${var.name}-bucket" })
}
resource "aws_s3_bucket_versioning" "app" {
  bucket = aws_s3_bucket.app.id
  versioning_configuration { status = "Enabled" }
}
resource "aws_s3_bucket_public_access_block" "app" {
  bucket = aws_s3_bucket.app.id
  block_public_acls=true block_public_policy=true ignore_public_acls=true restrict_public_buckets=true
}

# ALB logs bucket + lifecycle + policy
data "aws_elb_service_account" "sa" {}
resource "aws_s3_bucket" "alb_logs" {
  bucket = "${var.name}-${var.env}-alb-logs-${random_string.suffix.result}"
  tags   = merge(var.tags, { Purpose = "alb-logs" })
}
resource "aws_s3_bucket_ownership_controls" "own" {
  bucket = aws_s3_bucket.alb_logs.id
  rule { object_ownership = "BucketOwnerPreferred" }
}
resource "aws_s3_bucket_acl" "acl" {
  bucket = aws_s3_bucket.alb_logs.id
  acl    = "private"
  depends_on = [aws_s3_bucket_ownership_controls.own]
}
resource "aws_s3_bucket_public_access_block" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id
  block_public_acls=true block_public_policy=true ignore_public_acls=true restrict_public_buckets=true
}
resource "aws_s3_bucket_lifecycle_configuration" "lc" {
  bucket = aws_s3_bucket.alb_logs.id
  rule { id = "expire-90-days" status="Enabled" expiration { days=90 } }
}
resource "aws_s3_bucket_policy" "policy" {
  bucket = aws_s3_bucket.alb_logs.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid="Write", Effect="Allow",
        Principal={ AWS = data.aws_elb_service_account.sa.arn },
        Action=["s3:PutObject","s3:PutObjectAcl"],
        Resource="${aws_s3_bucket.alb_logs.arn}/AWSLogs/*",
        Condition={ StringEquals={ "s3:x-amz-acl"="bucket-owner-full-control" } }
      },
      { Sid="Check", Effect="Allow", Principal={ AWS=data.aws_elb_service_account.sa.arn }, Action="s3:GetBucketAcl", Resource=aws_s3_bucket.alb_logs.arn }
    ]
  })
}
