variable "account_id" {
  description = "AWS account ID"
  type        = string
}

variable "flag" {
  description = "CTF flag value stored in Secrets Manager"
  type        = string
  sensitive   = true
}
