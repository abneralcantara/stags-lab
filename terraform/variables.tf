variable "easy_flag" {
  description = "Flag value for the easy lab (Open Sesame)"
  type        = string
  default     = "CYBERWARGAMES{tr4ck_y0ur_trust_p0l1c135_c4r3fully}"
  sensitive   = true
}

variable "hard_flag" {
  description = "Flag value for the hard lab (The Lazy DevOps)"
  type        = string
  default     = "CYBERWARGAMES{1am_cr3at3_p0l1cy_v3rs10n_pr1v3sc}"
  sensitive   = true
}
