# ─────────────────────────────────────────────────────────────────────────────
# Lab 1 — "Open Sesame" (Easy)
#
# Misconfiguration: IAM role trust policy uses arn:aws:iam::ACCOUNT:root as
# principal instead of ec2.amazonaws.com, allowing any authenticated IAM
# entity in the account to assume the role.
#
# Anti-enumeration changes:
#   - iam:ListRoles and iam:GetRole removed — tools cannot enumerate or read
#     role trust policies directly; the role name is discovered via S3 hint.
#   - sts:AssumeRole scoped to "*" — player must try assumption after finding
#     the role name; the misconfigured trust policy is what makes it succeed.
#   - Decoy SSM parameters added — ssm:DescribeParameters output is noisy.
# ─────────────────────────────────────────────────────────────────────────────

resource "random_id" "hint_bucket_suffix" {
  byte_length = 4
}

locals {
  hint_bucket_name = "ctf-easy-artifacts-${random_id.hint_bucket_suffix.hex}"

  # Decoy SSM parameters — visible via ssm:DescribeParameters, values are
  # unremarkable strings that add noise without leaking anything sensitive.
  decoy_ssm_params = {
    "/config/ec2/instance_type"        = "t3.medium"
    "/config/monitoring/scrape_interval" = "60"
    "/config/monitoring/retention_days"  = "30"
    "/internal/deploy/last_version"     = "v2.4.1"
    "/internal/team/rotation_schedule"  = "weekly"
  }
}

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

# ── Starting policy ───────────────────────────────────────────────────────────
#
# iam:ListRoles and iam:GetRole intentionally omitted — automated enumeration
# tools (Pacu, enumerate-iam) rely on these to map the IAM role surface.
# Players must discover the target role name through the S3 hint bucket.
#
# sts:AssumeRole is open to "*" so the player can attempt assumption once they
# have the role name from the hint. Only the misconfigured role will accept.

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
        Sid    = "AssumeAnyRole"
        Effect = "Allow"
        Action = ["sts:AssumeRole"]
        # Open to * — the trust policy misconfiguration on ec2-monitoring-role
        # is what makes assumption succeed; correctly configured roles will deny.
        Resource = "*"
      },
      {
        Sid      = "DescribeParameters"
        Effect   = "Allow"
        Action   = ["ssm:DescribeParameters"]
        Resource = "*"
      },
      {
        Sid      = "S3ListBuckets"
        Effect   = "Allow"
        Action   = ["s3:ListAllMyBuckets"]
        Resource = "*"
      },
      {
        Sid    = "S3HintBucket"
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetObject",
        ]
        Resource = [
          "arn:aws:s3:::${local.hint_bucket_name}",
          "arn:aws:s3:::${local.hint_bucket_name}/*",
        ]
      },
    ]
  })
}

resource "aws_iam_user_policy_attachment" "player_policy" {
  user       = aws_iam_user.player.name
  policy_arn = aws_iam_policy.player_policy.arn
}

# ── S3 hint bucket ────────────────────────────────────────────────────────────
#
# Replaces iam:ListRoles as the role-discovery mechanism. Players must find
# this bucket and read the internal note to learn the target role name.

resource "aws_s3_bucket" "hints" {
  bucket = local.hint_bucket_name

  tags = {
    Lab = "easy"
  }
}

resource "aws_s3_bucket_public_access_block" "hints" {
  bucket = aws_s3_bucket.hints.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_object" "hint" {
  bucket       = aws_s3_bucket.hints.bucket
  key          = "internal/platform-notes.txt"
  content_type = "text/plain"

  content = <<-EOT
    Platform Engineering — Internal Notes
    ======================================

    EC2 Monitoring Tool — IAM Setup
    --------------------------------
    Role name : ec2-monitoring-role
    Purpose   : Automated metric collection from EC2 fleet via SSM
    Owner     : platform-eng@example.internal

    Deployment note (Q2):
    Trust policy is currently using account-level access for development
    convenience. Ticket open to restrict to specific instance profile
    before next compliance review.

    SSM paths used by the tool: /config/ec2/*, /config/monitoring/*

    — Platform Engineering
  EOT

  tags = {
    Lab = "easy"
  }
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

# ── Decoy SSM parameters (noise) ──────────────────────────────────────────────
#
# These appear in ssm:DescribeParameters output alongside /ctf/easy/flag,
# making the parameter list less immediately obvious to automated scanners.

resource "aws_ssm_parameter" "decoy" {
  for_each = local.decoy_ssm_params

  name  = each.key
  type  = "String"
  value = each.value

  tags = {
    Lab = "easy"
  }
}
