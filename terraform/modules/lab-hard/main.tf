# ─────────────────────────────────────────────────────────────────────────────
# Lab 2 — "The Lazy DevOps" (Hard)
#
# Misconfiguration: The player's inline policy grants iam:CreatePolicyVersion
# and iam:SetDefaultPolicyVersion on their own managed policy (ctf-hard-
# restricted), allowing them to inject new permissions into it.
#
# Player isolation: A permissions boundary hard-caps the player's effective
# permissions to only the actions needed to complete the lab, regardless of
# what they write into their managed policy after escalation.
# ─────────────────────────────────────────────────────────────────────────────

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

locals {
  bucket_name = "ctf-hard-artifacts-${random_id.bucket_suffix.hex}"
}

# ── Permissions boundary ──────────────────────────────────────────────────────
#
# Effective permissions = identity policies ∩ permissions boundary.
# Even a wildcard identity policy ("Action":"*") cannot exceed this boundary.
# The player can NEVER: read other labs' flags, modify other users/roles,
# delete infrastructure, or remove/modify this boundary.

resource "aws_iam_policy" "player_boundary" {
  name        = "ctf-hard-player-boundary"
  description = "Permissions boundary for ctf-hard-player — hard cap on effective permissions"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "IdentityAndEnumeration"
        Effect = "Allow"
        Action = [
          "sts:GetCallerIdentity",
          "iam:GetUser",
          "iam:ListAttachedUserPolicies",
          "iam:ListUserPolicies",
          "iam:GetUserPolicy",
          "iam:ListPolicies",
          "iam:GetPolicy",
          "iam:GetPolicyVersion",
          "iam:ListPolicyVersions",
        ]
        Resource = "*"
      },
      {
        Sid    = "PolicyVersionManagement"
        Effect = "Allow"
        Action = [
          "iam:CreatePolicyVersion",
          "iam:SetDefaultPolicyVersion",
        ]
        # Scoped to the player's own managed policy only
        Resource = "arn:aws:iam::${var.account_id}:policy/ctf-hard-restricted"
      },
      {
        Sid      = "S3ListAll"
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
          "arn:aws:s3:::${local.bucket_name}",
          "arn:aws:s3:::${local.bucket_name}/*",
        ]
      },
      {
        Sid    = "SecretsManagerFlag"
        Effect = "Allow"
        Action = ["secretsmanager:GetSecretValue"]
        # Scoped to the hard lab flag only — cannot read easy lab or any other secret
        Resource = "arn:aws:secretsmanager:sa-east-1:${var.account_id}:secret:ctf/hard/flag*"
      },
    ]
  })
}

# ── Player identity ───────────────────────────────────────────────────────────

resource "aws_iam_user" "player" {
  name = "ctf-hard-player"

  # Boundary is attached at creation — the player cannot remove or modify it
  permissions_boundary = aws_iam_policy.player_boundary.arn

  tags = {
    Lab = "hard"
  }
}

resource "aws_iam_access_key" "player" {
  user = aws_iam_user.player.name
}

# ── Managed policy — the escalation target ────────────────────────────────────
#
# Initially grants only sts:GetCallerIdentity.
# The player must use iam:CreatePolicyVersion to add secretsmanager access,
# making the escalation meaningful (boundary allows it, initial policy does not).

resource "aws_iam_policy" "restricted" {
  name        = "ctf-hard-restricted"
  description = "Restricted policy for ci-deploy bot — managed by pipeline self-update mechanism"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "BasicIdentity"
        Effect   = "Allow"
        Action   = ["sts:GetCallerIdentity"]
        Resource = "*"
      },
    ]
  })
}

resource "aws_iam_user_policy_attachment" "restricted" {
  user       = aws_iam_user.player.name
  policy_arn = aws_iam_policy.restricted.arn
}

# ── Inline policy — contains the misconfiguration ─────────────────────────────

resource "aws_iam_user_policy" "inline" {
  name = "ctf-hard-inline"
  user = aws_iam_user.player.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "IdentityAndEnumeration"
        Effect = "Allow"
        Action = [
          "sts:GetCallerIdentity",
          "iam:GetUser",
          "iam:ListAttachedUserPolicies",
          "iam:ListUserPolicies",
          "iam:GetUserPolicy",
          "iam:ListPolicies",
          "iam:GetPolicy",
          "iam:GetPolicyVersion",
          "iam:ListPolicyVersions",
        ]
        Resource = "*"
      },
      {
        Sid    = "SelfManagedPolicyUpdate"
        Effect = "Allow"
        # INTENTIONAL MISCONFIGURATION:
        # Grants the player the ability to create new versions of their own
        # managed policy and set them as default — a well-known IAM privesc
        # primitive. A pipeline bot should never have write access to its
        # own policy document.
        Action = [
          "iam:CreatePolicyVersion",
          "iam:SetDefaultPolicyVersion",
        ]
        Resource = aws_iam_policy.restricted.arn
      },
      {
        Sid      = "S3ListAll"
        Effect   = "Allow"
        Action   = ["s3:ListAllMyBuckets"]
        Resource = "*"
      },
      {
        Sid    = "S3HintBucketRead"
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetObject",
        ]
        Resource = [
          aws_s3_bucket.artifacts.arn,
          "${aws_s3_bucket.artifacts.arn}/*",
        ]
      },
    ]
  })
}

# ── S3 hint bucket ────────────────────────────────────────────────────────────

resource "aws_s3_bucket" "artifacts" {
  bucket = local.bucket_name

  tags = {
    Lab = "hard"
  }
}

resource "aws_s3_bucket_public_access_block" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_object" "hint" {
  bucket       = aws_s3_bucket.artifacts.bucket
  key          = "hints/README.txt"
  content_type = "text/plain"

  content = <<-EOT
    Internal note — DevOps team

    The ci-deploy bot has been set up with self-managed policy versioning
    to allow automated permission updates during deployments.

    Policy ARN: ${aws_iam_policy.restricted.arn}

    If you're reading this, you're either the team or... you shouldn't be here.
    Good luck either way.
  EOT

  tags = {
    Lab = "hard"
  }
}

# ── Flag ──────────────────────────────────────────────────────────────────────

resource "aws_secretsmanager_secret" "flag" {
  name                    = "ctf/hard/flag"
  description             = "CTF flag for the hard lab — readable only after policy escalation"
  recovery_window_in_days = 0

  tags = {
    Lab = "hard"
  }
}

resource "aws_secretsmanager_secret_version" "flag" {
  secret_id     = aws_secretsmanager_secret.flag.id
  secret_string = var.flag
}

# ── Policy auto-reset mechanism ───────────────────────────────────────────────
#
# Problem: iam:CreatePolicyVersion modifies shared AWS state. Once Player 1
# escalates ctf-hard-restricted to v2, subsequent players already have the
# elevated policy active and can skip the entire escalation step.
#
# Fix: an EventBridge-triggered Lambda runs every 5 minutes. It deletes any
# non-original versions of ctf-hard-restricted and restores v1 as default,
# resetting the lab for the next player. Players must escalate and read the
# flag within the reset window.

locals {
  original_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "BasicIdentity"
        Effect   = "Allow"
        Action   = ["sts:GetCallerIdentity"]
        Resource = "*"
      }
    ]
  })
}

# Package the Lambda function code
data "archive_file" "reset_lambda" {
  type        = "zip"
  output_path = "${path.module}/reset_lambda.zip"

  source {
    filename = "reset.py"
    content  = <<-PYTHON
      import boto3, json, os

      iam = boto3.client('iam')

      def handler(event, context):
          policy_arn = os.environ['POLICY_ARN']
          original   = os.environ['ORIGINAL_POLICY']

          versions   = iam.list_policy_versions(PolicyArn=policy_arn)['Versions']
          default_id = next(v['VersionId'] for v in versions if v['IsDefaultVersion'])

          # If already clean (single version, correct content) — nothing to do
          if len(versions) == 1:
              doc = iam.get_policy_version(
                  PolicyArn=policy_arn, VersionId=default_id
              )['PolicyVersion']['Document']
              if json.dumps(doc, sort_keys=True) == json.dumps(json.loads(original), sort_keys=True):
                  print('Policy already at original state — no action needed')
                  return {'status': 'clean'}

          # Step 1: delete all non-default versions to free up slots
          for v in versions:
              if not v['IsDefaultVersion']:
                  iam.delete_policy_version(PolicyArn=policy_arn, VersionId=v['VersionId'])
                  print(f'Deleted non-default version {v["VersionId"]}')

          # Step 2: create a fresh version with the original content and set as default
          iam.create_policy_version(
              PolicyArn=policy_arn,
              PolicyDocument=original,
              SetAsDefault=True,
          )
          print('Created fresh version with original content and set as default')

          # Step 3: delete the old default (which may have been the escalated version)
          iam.delete_policy_version(PolicyArn=policy_arn, VersionId=default_id)
          print(f'Deleted old default version {default_id}')

          return {'status': 'reset complete'}
    PYTHON
  }
}

# IAM execution role for the Lambda
resource "aws_iam_role" "reset_lambda" {
  name = "ctf-hard-policy-reset-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Lab = "hard"
  }
}

resource "aws_iam_role_policy" "reset_lambda" {
  name = "ctf-hard-policy-reset-policy"
  role = aws_iam_role.reset_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ResetTargetPolicy"
        Effect = "Allow"
        Action = [
          "iam:ListPolicyVersions",
          "iam:GetPolicyVersion",
          "iam:CreatePolicyVersion",
          "iam:DeletePolicyVersion",
        ]
        Resource = aws_iam_policy.restricted.arn
      },
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
        ]
        Resource = "arn:aws:logs:sa-east-1:${var.account_id}:log-group:/aws/lambda/ctf-hard-policy-reset:*"
      },
    ]
  })
}

# CloudWatch Log Group (7-day retention to keep costs near zero)
resource "aws_cloudwatch_log_group" "reset_lambda" {
  name              = "/aws/lambda/ctf-hard-policy-reset"
  retention_in_days = 7

  tags = {
    Lab = "hard"
  }
}

# Lambda function
resource "aws_lambda_function" "reset" {
  function_name = "ctf-hard-policy-reset"
  description   = "Resets ctf-hard-restricted to its original single-version state every 5 minutes"
  role          = aws_iam_role.reset_lambda.arn
  runtime       = "python3.12"
  handler       = "reset.handler"
  timeout       = 30

  filename         = data.archive_file.reset_lambda.output_path
  source_code_hash = data.archive_file.reset_lambda.output_base64sha256

  environment {
    variables = {
      POLICY_ARN      = aws_iam_policy.restricted.arn
      ORIGINAL_POLICY = local.original_policy
    }
  }

  depends_on = [aws_cloudwatch_log_group.reset_lambda]

  tags = {
    Lab = "hard"
  }
}

# EventBridge rule — fires every 5 minutes
resource "aws_cloudwatch_event_rule" "reset" {
  name                = "ctf-hard-policy-reset-schedule"
  description         = "Triggers the policy reset Lambda every 5 minutes"
  schedule_expression = "rate(5 minutes)"

  tags = {
    Lab = "hard"
  }
}

resource "aws_cloudwatch_event_target" "reset" {
  rule      = aws_cloudwatch_event_rule.reset.name
  target_id = "ctf-hard-policy-reset"
  arn       = aws_lambda_function.reset.arn
}

resource "aws_lambda_permission" "reset" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.reset.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.reset.arn
}
