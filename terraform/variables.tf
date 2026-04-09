variable "easy_flag" {
  description = "Flag value for the easy lab (Open Sesame)"
  type        = string
  default     = "{CWG:Tr4ck_Y0ur_L1f4_C4r3fully:603b46b2644163956691c747a20485a3348f4954daf365a5bd7bef5a65e15013}"
  sensitive   = true
}

variable "hard_flag" {
  description = "Flag value for the hard lab (The Lazy DevOps)"
  type        = string
  default     = "{CWG:1am_D3str0y3r_0f_P0l1c13s:ea5d7463d266068403d522f74fd40ab9373352935234e2eccb9e821a578ac998}"
  sensitive   = true
}
