variable "aws_region" {
  description = "AWS region to deploy ECR repositories"
  type        = string
  default     = "us-east-1"
}

variable "aws_account_id" {
  description = "AWS account ID (used to construct ECR push URLs). Pass via TF_VAR_aws_account_id or -var flag."
  type        = string
}

variable "repo_count" {
  description = "Total number of ECR repositories to create"
  type        = number
  default     = 20
}

variable "repo_prefix" {
  description = "Prefix for repository names (e.g. 'react-app' => react-app-01 ... react-app-20)"
  type        = string
  default     = "react-app"
}

variable "poisoned_repo_index" {
  description = "1-based index of the repository that contains the leaked IAM credentials"
  type        = number
  default     = 7
}

variable "image_tag" {
  description = "Docker image tag to push to every repository"
  type        = string
  default     = "latest"
}
