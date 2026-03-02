# ── Locals ───────────────────────────────────────────────────────────────────

locals {
  # Generate the full set of repo names: react-app-01 … react-app-20
  repo_names = toset([
    for i in range(1, var.repo_count + 1) :
    format("%s-%02d", var.repo_prefix, i)
  ])

  # The single repository that will contain the leaked IAM credentials
  poisoned_repo_name = format("%s-%02d", var.repo_prefix, var.poisoned_repo_index)

  # ECR registry hostname
  ecr_registry = "${var.aws_account_id}.dkr.ecr.${var.aws_region}.amazonaws.com"

  # Absolute path to the Docker build-context directory
  build_context_path = abspath("${path.module}/../docker")
}

# ── ECR Repositories (20 total) ──────────────────────────────────────────────

resource "aws_ecr_repository" "repos" {
  for_each = local.repo_names

  name                 = each.value
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = false
  }

  # Allow Terraform destroy even when images are present
  force_delete = true

  tags = {
    Project   = "stags-lab"
    Challenge = "ecr-react-ctf"
    Env       = "lab"
  }
}

# ── ECR Lifecycle Policy (keep last 3 images per repo) ───────────────────────

resource "aws_ecr_lifecycle_policy" "repos" {
  for_each   = local.repo_names
  repository = aws_ecr_repository.repos[each.value].name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep only the last 3 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 3
        }
        action = { type = "expire" }
      }
    ]
  })
}

# ── Docker ECR Login (runs once; all pushes reuse the cached token) ──────────

resource "null_resource" "ecr_login" {
  triggers = {
    registry = local.ecr_registry
  }

  provisioner "local-exec" {
    command = <<-EOT
      aws ecr get-login-password --region ${var.aws_region} | \
        docker login --username AWS --password-stdin ${local.ecr_registry}
    EOT
  }

  depends_on = [aws_ecr_repository.repos]
}

# ── Docker Build & Push for every repository ─────────────────────────────────
#
# Strategy: a temporary isolated build context is created per repo.
# For the poisoned repo (react-app-07), aws_config.py is injected into
# the temp context before building, so only that image's layers contain
# the credentials file. The file is never present in the other 19 images.

resource "null_resource" "docker_build_push" {
  for_each = local.repo_names

  triggers = {
    repo_url        = aws_ecr_repository.repos[each.value].repository_url
    poisoned_repo   = local.poisoned_repo_name
    dockerfile_hash = filemd5("${local.build_context_path}/Dockerfile")
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -euo pipefail

      REPO_NAME="${each.value}"
      REPO_URL="${aws_ecr_repository.repos[each.value].repository_url}"
      IMAGE_TAG="${var.image_tag}"
      BUILD_CONTEXT="${local.build_context_path}"
      POISONED_REPO="${local.poisoned_repo_name}"

      # ── 1. Create a temporary, isolated copy of the build context ──────────
      TMP_CTX=$(mktemp -d)
      trap "rm -rf $TMP_CTX" EXIT

      cp -r "$BUILD_CONTEXT/." "$TMP_CTX/"

      # ── 2. Inject credentials ONLY for the poisoned repository ─────────────
      if [ "$REPO_NAME" = "$POISONED_REPO" ]; then
        mkdir -p "$TMP_CTX/react-app/src/scripts"
        cp "$BUILD_CONTEXT/react-app/src/scripts/aws_config.py" \
           "$TMP_CTX/react-app/src/scripts/aws_config.py"
        echo "[+] Injected aws_config.py into build context for $REPO_NAME"
      else
        # Remove scripts dir from the clean context to ensure no file leaks
        rm -rf "$TMP_CTX/react-app/src/scripts"
      fi

      # ── 3. Build ────────────────────────────────────────────────────────────
      docker build \
        --network=host \
        --build-arg REPO_NAME="$REPO_NAME" \
        -t "$REPO_URL:$IMAGE_TAG" \
        "$TMP_CTX"

      # ── 4. Push ─────────────────────────────────────────────────────────────
      docker push "$REPO_URL:$IMAGE_TAG"

      echo "[+] Done: $REPO_NAME -> $REPO_URL:$IMAGE_TAG"
    EOT
  }

  depends_on = [null_resource.ecr_login]
}
