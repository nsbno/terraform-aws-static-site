# ------------------------------------------------------------------------------
# Output
# ------------------------------------------------------------------------------
output "website_bucket_id" {
  value = data.aws_s3_bucket.website_bucket.id
}

output "website_bucket_arn" {
  value = data.aws_s3_bucket.website_bucket.arn
}

output "initial_bucket_policy" {
  value = data.aws_iam_policy_document.s3_policy.json
}

