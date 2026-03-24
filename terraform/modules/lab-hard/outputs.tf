output "access_key_id" {
  description = "Access key ID for ctf-hard-player"
  value       = aws_iam_access_key.player.id
}

output "secret_access_key" {
  description = "Secret access key for ctf-hard-player"
  value       = aws_iam_access_key.player.secret
  sensitive   = true
}

output "hint_bucket" {
  description = "S3 bucket containing the hint file"
  value       = aws_s3_bucket.artifacts.bucket
}
