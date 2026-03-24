output "easy_lab" {
  description = "Player credentials for Lab 1 — Open Sesame (Easy)"
  sensitive   = true
  value = {
    lab               = "Open Sesame (Easy)"
    username          = "ctf-easy-player"
    access_key_id     = module.lab_easy.access_key_id
    secret_access_key = module.lab_easy.secret_access_key
    region            = "sa-east-1"
  }
}

output "hard_lab" {
  description = "Player credentials for Lab 2 — The Lazy DevOps (Hard)"
  sensitive   = true
  value = {
    lab               = "The Lazy DevOps (Hard)"
    username          = "ctf-hard-player"
    access_key_id     = module.lab_hard.access_key_id
    secret_access_key = module.lab_hard.secret_access_key
    region            = "sa-east-1"
  }
}
