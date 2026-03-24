# ─────────────────────────────────────────────────────────────────────────────
# Lab 1 — "Open Sesame" (Easy)
#
# Misconfiguration: IAM role trust policy uses arn:aws:iam::ACCOUNT:root as
# principal instead of ec2.amazonaws.com, allowing any authenticated IAM
# entity in the account to assume the role.
# ─────────────────────────────────────────────────────────────────────────────

# ── Player identity ──────────────────────────────────────────────────────────

resource "aws_iam_user" "player" {
  name = "ctf-easy-player"

  tags = {
    Lab = "easy"
  }
}

resource "aws_iam_access_key" "player" {
  user = aws_iam_user.player.name
}

# ── Starting policy: enumerate roles + assume the target role ─────────────────

resource "aws_iam_policy" "player_policy" {
  name        = "ctf-easy-player-policy"
  description = "Starting permissions for the easy CTF lab player"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "IdentityCheck"
        Effect   = "Allow"
        Action   = ["sts:GetCallerIdentity"]
        Resource = "*"
      },
      {
        Sid    = "EnumerateRoles"
        Effect = "Allow"
        Action = [
          "iam:ListRoles",
          "iam:GetRole",
        ]
        Resource = "*"
      },
      {
        Sid    = "AssumeTargetRole"
        Effect = "Allow"
        Action = ["sts:AssumeRole"]
        # Scoped to the single target role — player cannot assume anything else
        Resource = aws_iam_role.monitoring.arn
      },
      {
        Sid      = "DescribeParameters"
        Effect   = "Allow"
        Action   = ["ssm:DescribeParameters"]
        Resource = "*"
      },
    ]
  })
}

resource "aws_iam_user_policy_attachment" "player_policy" {
  user       = aws_iam_user.player.name
  policy_arn = aws_iam_policy.player_policy.arn
}

# ── Misconfigured IAM role ────────────────────────────────────────────────────

resource "aws_iam_role" "monitoring" {
  name        = "ec2-monitoring-role"
  description = "Role for the internal EC2 monitoring tool"

  # INTENTIONAL MISCONFIGURATION:
  # Principal should be { Service = "ec2.amazonaws.com" }.
  # Using the account root allows ANY authenticated IAM entity in the account
  # to call sts:AssumeRole on this role — not just the EC2 service.
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.account_id}:root"
        }
        Action = "sts:AssumeRole"
      },
    ]
  })

  tags = {
    Lab = "easy"
  }
}

resource "aws_iam_role_policy" "monitoring_ssm" {
  name = "ssm-read-flag"
  role = aws_iam_role.monitoring.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ReadEasyFlag"
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
        ]
        # Scoped to easy lab path only — cannot read hard lab secrets
        Resource = "arn:aws:ssm:sa-east-1:${var.account_id}:parameter/ctf/easy/*"
      },
      {
        Sid      = "IdentityCheck"
        Effect   = "Allow"
        Action   = ["sts:GetCallerIdentity"]
        Resource = "*"
      },
    ]
  })
}

# ── Flag ──────────────────────────────────────────────────────────────────────

resource "aws_ssm_parameter" "flag" {
  name        = "/ctf/easy/flag"
  description = "CTF flag for the easy lab — readable only via ec2-monitoring-role"
  type        = "SecureString"
  value       = var.flag

  tags = {
    Lab = "easy"
  }
}
