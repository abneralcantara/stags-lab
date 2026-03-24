output "access_key_id" {
  description = "Access key ID for ctf-easy-player"
  value       = aws_iam_access_key.player.id
}

output "secret_access_key" {
  description = "Secret access key for ctf-easy-player"
  value       = aws_iam_access_key.player.secret
  sensitive   = true
}
