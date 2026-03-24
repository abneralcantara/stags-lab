# Terraform — AWS CTF Labs

Deploys two IAM privilege escalation labs in AWS (`sa-east-1`).

| Lab | Name | Misconfiguration | Flag storage |
|-----|------|-----------------|--------------|
| Easy | Open Sesame | IAM role trust policy allows account root principal | SSM Parameter Store |
| Hard | The Lazy DevOps | `iam:CreatePolicyVersion` granted on own managed policy | Secrets Manager |

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.5.0
- AWS credentials with permissions to manage IAM, SSM, S3, and Secrets Manager
- An isolated AWS account dedicated to this CTF

## Deploy

```bash
cd terraform/

# Initialise providers
terraform init

# Preview what will be created
terraform plan

# Deploy
terraform apply
```

## Get player credentials

Outputs are marked sensitive. Retrieve them with:

```bash
# Pretty-print both labs
terraform output -json | jq '{
  easy: .easy_lab.value,
  hard: .hard_lab.value
}'

# Individual values
terraform output -json easy_lab | jq -r '.access_key_id, .secret_access_key'
terraform output -json hard_lab | jq -r '.access_key_id, .secret_access_key'
```

Hand each player their lab's `access_key_id`, `secret_access_key`, and region (`sa-east-1`).

## Configure AWS CLI as a player

```bash
aws configure --profile ctf-easy
# AWS Access Key ID:     <easy access_key_id>
# AWS Secret Access Key: <easy secret_access_key>
# Default region:        sa-east-1
# Default output format: json

aws sts get-caller-identity --profile ctf-easy
```

## Destroy

```bash
terraform destroy
```

> **Note**: Secrets Manager secrets with `recovery_window_in_days = 0` are deleted
> immediately on destroy with no recovery window.

## Cost

All resources are IAM, SSM Parameter Store, S3, and Secrets Manager.
Estimated cost: **< $0.01 / hour**.
