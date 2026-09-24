output "bucket_arn" {
  description = "ARN of the flow logs bucket (pass to the vpc module's flow_log_destination_arn)."
  value       = aws_s3_bucket.this.arn

  # Consumers (flow logs) must not be created before the delivery policy exists.
  depends_on = [aws_s3_bucket_policy.this]
}

output "bucket_name" {
  description = "Name of the flow logs bucket."
  value       = aws_s3_bucket.this.id
}
