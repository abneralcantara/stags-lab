# ECR React App CTF Challenge

## Scenario

A development team has deployed **20 React web application microservices** to AWS ECR.
During a routine security review, an alert was raised: one of the Docker images may contain
hardcoded AWS IAM programmatic credentials accidentally left behind by a developer.

Your mission is to find **which image** contains the credentials and extract the CTF flag.

---

## Objectives

1. Enumerate all 20 ECR repositories
2. Pull each Docker image and inspect its filesystem
3. Locate the Python script containing the leaked IAM credentials
4. Extract the CTF flag from the script

---

## Architecture

```
AWS ECR
├── react-app-01   (React dashboard — clean)
├── react-app-02   (React dashboard — clean)
├── ...
├── react-app-07   (React dashboard — !! leaked credentials !!)
├── ...
└── react-app-20   (React dashboard — clean)
```

All 20 images serve an identical React web application over HTTP via nginx.
Only **one** image's filesystem contains a Python configuration script
(`aws_config.py`) with hardcoded IAM credentials.

---

## Infrastructure Deployment

### Prerequisites

- Terraform >= 1.5
- AWS CLI configured with credentials that can create ECR repositories
- Docker (running locally and logged into ECR)

### Deploy

```bash
cd ecr-challenge/terraform/

terraform init

terraform apply \
  -var="aws_account_id=$(aws sts get-caller-identity --query Account --output text)"
```

Terraform will:
1. Create 20 ECR repositories (`react-app-01` … `react-app-20`)
2. Build a React Docker image for each repository
3. Inject the credentials file into exactly one image's build context
4. Push all 20 images to ECR

After `apply`, the `answer` output reveals the credential location (intended for lab operators, not participants).

### Destroy

```bash
terraform destroy \
  -var="aws_account_id=$(aws sts get-caller-identity --query Account --output text)"
```

---

## Challenge — Participant Instructions

### 1. Authenticate to ECR

```bash
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION="us-east-1"

aws ecr get-login-password --region $REGION | \
  docker login --username AWS --password-stdin \
  "$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com"
```

### 2. List all repositories

```bash
aws ecr describe-repositories \
  --query 'repositories[*].repositoryName' \
  --output table
```

### 3. Hunt for the credentials

Pull each image and check for the Python configuration script:

```bash
REGISTRY="$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com"

for i in $(seq -w 01 20); do
  IMG="$REGISTRY/react-app-$i:latest"
  docker pull "$IMG" --quiet
  RESULT=$(docker run --rm "$IMG" cat /app/src/scripts/aws_config.py 2>/dev/null)
  if [ -n "$RESULT" ]; then
    echo ">>> FOUND in react-app-$i <<<"
    echo "$RESULT"
    break
  fi
done
```

### 4. Inspect individual images

```bash
# Open a shell inside a container
docker run --rm -it $REGISTRY/react-app-07:latest sh

# Or read the file directly
docker run --rm $REGISTRY/react-app-07:latest \
  cat /app/src/scripts/aws_config.py
```

### 5. Inspect image layers (advanced)

```bash
# See all files added in each layer
docker history --no-trunc $REGISTRY/react-app-07:latest

# Export the image and inspect layers manually
docker save $REGISTRY/react-app-07:latest | tar -xv
```

---

## Flag Format

```
CTF{...}
```

---

## Answer (Operators Only)

| Field            | Value                              |
|------------------|------------------------------------|
| Repository       | `react-app-07`                     |
| Image tag        | `latest`                           |
| File path        | `/app/src/scripts/aws_config.py`   |
| File type        | Python 3 module                    |

---

## Security Lesson

Docker images stored in **private** ECR repositories are **not** a secure
location for secrets. Anyone with `ecr:GetAuthorizationToken` +
`ecr:BatchGetImage` permissions can pull any image and read every file in
every layer — including files added during the build process.

**Correct approaches for secrets in containerized applications:**

| Method | Description |
|--------|-------------|
| IAM Roles (EC2/ECS/EKS) | Attach a role; no credentials in code |
| AWS Secrets Manager | Fetch at runtime; rotate automatically |
| Environment variables | Injected at deploy time; never baked in |
| Parameter Store | Secure, versioned configuration |

**Never** hardcode credentials, even in "internal" Docker images.
