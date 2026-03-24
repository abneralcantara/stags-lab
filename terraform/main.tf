data "aws_caller_identity" "current" {}

module "lab_easy" {
  source = "./modules/lab-easy"

  account_id = data.aws_caller_identity.current.account_id
  flag       = var.easy_flag
}

module "lab_hard" {
  source = "./modules/lab-hard"

  account_id = data.aws_caller_identity.current.account_id
  flag       = var.hard_flag
}
