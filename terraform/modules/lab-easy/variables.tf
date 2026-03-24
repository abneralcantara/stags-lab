variable "account_id" {
  description = "AWS account ID"
  type        = string
}

variable "flag" {
  description = "CTF flag value stored in SSM Parameter Store"
  type        = string
  sensitive   = true
}
