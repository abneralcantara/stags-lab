output "total_repositories" {
  description = "Number of ECR repositories created"
  value       = length(aws_ecr_repository.repos)
}

output "repository_urls" {
  description = "Map of repository name to ECR URL"
  value = {
    for name, repo in aws_ecr_repository.repos :
    name => repo.repository_url
  }
}

output "poisoned_repository" {
  description = "Name of the ECR repository that contains the leaked IAM credentials"
  value       = local.poisoned_repo_name
}

output "poisoned_repository_url" {
  description = "Full ECR URL of the repository containing the leaked credentials"
  value       = aws_ecr_repository.repos[local.poisoned_repo_name].repository_url
}

output "credentials_file_path" {
  description = "Absolute path inside the container where the credentials script is stored"
  value       = "/app/src/scripts/aws_config.py"
}

output "answer" {
  description = "Full answer: which container and path hold the IAM credentials"
  value = join("\n", [
    "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
    "  ECR REACT CTF — Credential Location",
    "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
    "  Repository : ${local.poisoned_repo_name}",
    "  Image tag  : ${var.image_tag}",
    "  ECR URL    : ${aws_ecr_repository.repos[local.poisoned_repo_name].repository_url}",
    "  File path  : /app/src/scripts/aws_config.py",
    "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
  ])
}
