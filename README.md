# Terraform Module - AWS Account Bootstrap

## Overview

**AWS Account Bootstrap** is a **platform-owned, enterprise-grade bootstrap framework** that uses **GitHub Actions** to orchestrate a **Terraform module** for initializing new AWS accounts in a **standardized**, **secure**, and **auditable manner**.

This bootstrap is a **one-time operation per AWS account** and establishes the foundational components required for all future Terraform-based infrastructure deployments, including:

- Secure Terraform remote state storage (Amazon S3)
- Native Terraform locking (S3 native locking, **no DynamoDB**)
- Standardized IAM access for GitHub Actions via **OIDC-based two-hop authentication**
- Enterprise tagging and traceability
- Centralized logging and auditability

Once bootstrap is completed, all downstream Terraform modules can safely rely on the created backend and IAM roles.

--- 

## Repository Responsibility & Usage Model

This repository serves as a **centralized platform bootstrap repository**.

It contains:

1. A **Terraform bootstrap module** responsible for provisioning
   foundational AWS account resources (state backend, logging, IAM access).
2. A **reusable GitHub Actions workflow** that executes the bootstrap module
   in a consistent, controlled, and auditable manner.

### How This Repository Is Used

- The bootstrap workflow can be triggered for **any AWS account**, **any environment**, and **any workload or application**.
- The workflow dynamically determines the target account and environment using input parameters
  (for example: `tower`, `environment`, account mapping).
- This repository is **not application-specific** and must **not be duplicated per application**.

### Application Interaction Model

- Application repositories **do not run Terraform bootstrap themselves**.
- Applications consume the **outputs** of this bootstrap:
  - Pre-configured Terraform S3 backend
  - Standardized IAM roles for GitHub Actions
- All application-level Terraform code assumes the bootstrap has already been completed.

This enforces:
- A single source of truth for account initialization
- Consistent security and audit controls
- Clear separation between platform bootstrap and application infrastructure

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Bootstrap Workflow Responsibilities](#bootstrap-workflow-responsibilities)
3. [Authentication Model (Enterprise)](#authentication-model-enterprise)
   - [GitHub App](#github-app-source-code-access)
   - [OIDC Provider](#github-actions-oidc-provider)
   - [Two-Hop Role Assumption](#two-hop-authentication-recommended-pattern)
   - [sts:TagSession (Justification)](#ststagsession-why-it-is-required)
4. [Prerequisites](#prerequisites)
5. [Logging & Audit Model](#logging--audit-model)
6. [Terraform State & Locking Strategy](#terraform-state--locking-strategy)
   - [Terraform Native State Locking (S3)](#terraform-native-state-locking-s3)
   - [Backend Bootstrap Model](#backend-bootstrap-model)
   - [S3 Bucket Classification](#s3-bucket-classification)
7. [Workflow Execution Flow](#workflow-execution-flow)
8. [Running the Bootstrap Workflow](#running-the-bootstrap-workflow)
9. [Failure & Recovery Model](#failure--recovery-model)
10. [Terraform Module Structure](#terraform-module-structure)
    - [main.tf](#maintf)
    - [variables.tf](#variablestf)
    - [outputs.tf](#outputstf)
11. [Enterprise Best Practices](#enterprise-best-practices)
12. [Out of Scope/Non Goals](#out-of-scope--non-goals)
13. [Security Considerations](#security-considerations)
14. [Summary](#summary)

---

## Architecture Overview

```
GitHub Actions (Repo)
        |
        |  GitHub App Token (repo/module access)
        v
GitHub Actions OIDC Provider
        |
        |  sts:AssumeRoleWithWebIdentity
        v
Org / Management AWS Account
(IAM Bootstrap Role)
        |
        |  sts:AssumeRole (+ sts:TagSession)
        v
Target AWS Account
(Bootstrap IAM Role)
        |
        v
Terraform (S3 Backend + Native Locking)
```

---

## Bootstrap Workflow Responsibilities

The bootstrap workflow performs the following:

- Resolves target AWS account ID based on **tower (workload_tower)** & **environment**
- Authenticates securely using OIDC (no static AWS credentials)
- Ensure the Terraform backend S3 bucket exists (created via workflow if missing)
- Provision and fully manage Terraform state and access logging buckets using Terraform
- Enable versioning, encryption, and public access block
- Generate backend config dynamically
- Run Terraform apply with approvals

This workflow is idempotent and safe to re-run.

---

## Authentication Model (Enterprise)

### GitHub App (Source Code Access)

A GitHub App is used to generate a short-lived token for:
- Accessing private Terraform modules
- Supporting GitHub Enterprise (e.g. abc.ghe.com)
- Enforcing org-wide repo access policies

This token is not used for AWS authentication.

### GitHub Actions OIDC Provider
Each AWS account trusts the GitHub Actions OIDC provider:

  ```yml
  arn:aws:iam::<ORG_ACCOUNT_ID>:oidc-provider/token.actions.githubusercontent.com
  ```

OIDC removes the need for long-lived AWS access keys.

### Two-Hop Authentication (Recommended Pattern)

**Hop 1: GitHub → Org / Management Account**
  - GitHub Actions assumes a role in the org account using OIDC
  - This role is tightly scoped and centrally audited via GitHub organization policies, GitHub Environments, and AWS CloudTrail.

**Hop 2: Org Account → Target Account**
  - Using temporary credentials from hop 1
  - Terraform assumes the same role name in the target account(workload account)

**Benefits:**
  - Centralized access control
  - No direct GitHub trust in workload accounts
  - Scales to hundreds of accounts

### sts:TagSession (Why It Is Required)

The bootstrap roles allow sts:TagSession.

**Why?**
  - GitHub Actions automatically injects session tags
  - Tags include:
    - Repository
    - Workflow
    - Actor
	- AWS requires sts:TagSession permission when tags are present

Without this permission, role assumption fails in enterprise setups.

Session tags improve:
  - CloudTrail attribution
  - Security investigations
  - Cost allocation

---

## Prerequisites

### AWS

- AWS Organizations enabled
- Org/Management account
- OIDC IAM roles created in Org account
- OIDC role in target accounts
- Trust relationship between org and target roles
- GitHub OIDC provider configured

### GitHub

- GitHub App installed on required orgs/repos
- Secrets configured:
  - `GH_APP_ID`
  - `GH_APP_PRIVATE_KEY`

These secrets can be configured at org level/repo level secrets. For Day 2, these secrets will be stored in COMM account secret manager.

---

## Logging & Audit Model

**Terraform State**
- Stored in S3 bootstrap bucket
- Versioned
- Encrypted

**GitHub Actions**
- Full execution logs retained by GitHub
- Approval gates recorded via Environments

**AWS CloudTrail**
- Captures:
	- OIDC role assumptions
	- sts:AssumeRole hops
	- Session tags

This provides end-to-end traceability from GitHub commit → AWS API call.

---

## Terraform State & Locking Strategy

### Terraform Native State Locking (S3)

This bootstrap uses **Terraform native S3 state locking** (`use_lockfile = true`).

Important clarifications:

- State locking is enforced using a `.tflock` object stored in the same S3 bucket as the Terraform state
- Locking is handled entirely by Terraform and Amazon S3
- No DynamoDB table is required
- This approach provides safe, atomic state locking with minimal infrastructure and lower operational overhead.
- lifecycle rule configured to remove noncurrent version post 365 days

Benefits:
- Simpler architecture
- Lower cost
- Terraform ≥ 1.10 required

### Backend Bootstrap Model

Terraform backends cannot create their own storage.

To solve this bootstrap problem, the workflow:
1. Creates a minimal S3 backend bucket using AWS CLI if it does not already exist
2. Initializes Terraform using that bucket as the backend
3. Uses Terraform to fully manage and harden the bucket configuration thereafter

This design ensures:
- Idempotent bootstrap execution
- Safe re-runs
- No circular dependency between Terraform and its backend

### S3 Bucket Classification

The bootstrap process creates and manages multiple S3 buckets with distinct responsibilities:

- **Backend bucket** (`${var.tower}-${var.environment}-terraform-${data.aws_caller_identity.current.id}-backend`)  
  Used to bootstrap Terraform remote state initialization.

- **State bucket** (`${var.tower}-${var.environment}-terraform-${data.aws_caller_identity.current.id}`)  
  Stores Terraform state for platform-level resources.

- **Logging bucket** (`${var.tower}-${var.environment}-terraform-${data.aws_caller_identity.current.id}-logs`)  
  Stores access logs for the Terraform state bucket.

Each bucket is clearly tagged to indicate purpose, ownership, and lifecycle.

---

## Workflow Execution Flow

1. Manual trigger (`workflow_dispatch`)
2. GitHub App token generation
3. Print Initial summary(workflow context logging)
4. Resolve AWS account ID from account mapping
5. Authenticate via OIDC (two-hop)
6. Create bootstrap S3 bucket (if missing)
7. Generate backend + tfvars
8. Terraform init + plan
9. Approval gate
10. Terraform apply

---

## Running the Bootstrap Workflow

The bootstrap process is executed via a **reusable GitHub Actions workflow** defined in this repository.

### How the Workflow Is Triggered

- The workflow is triggered manually using `workflow_dispatch`
- Execution requires appropriate GitHub permissions and environment approvals
- Only platform or cloud administrators are expected to run this workflow

### Required Inputs

At a minimum, the workflow requires:
- `tower` – Workload tower identifier
- `environment` – Target environment (e.g. dev, tst, ppe, prd)
- Account Mapping must be present under reusable action.

### Execution Model
- The workflow performs a minimal pre-Terraform bootstrap step to ensure the remote backend exists before Terraform initialization.
- The workflow dynamically resolves the target AWS account
- It assumes platform-managed IAM roles using OIDC (two-hop)
- Terraform is executed in a fully automated and auditable manner

> Application teams must **not** invoke this workflow directly.
> Bootstrap execution is a **platform-owned responsibility**.

### Access Control

Execution of the bootstrap workflow is restricted using:
- GitHub Environments
- Required reviewers / approval gates
- IAM trust policies scoped to platform roles

This ensures bootstrap actions cannot be executed accidentally or without authorization.

---

## Failure & Recovery Model

- The bootstrap workflow is **idempotent** and safe to re-run.
- If execution fails mid-run:
  - Previously created resources are reused
  - No destructive actions are performed
- Terraform state is protected via:
  - `prevent_destroy`
  - Explicit S3 bucket deletion deny policies

In the event of misconfiguration, recovery requires **manual intervention by a platform administrator**.

---

## Terraform Module Structure

### main.tf
```hcl
# This file contains the Terraform configuration used to provision s3 bucket for terraform statefile
# as well as server access logging bucket
terraform {
  required_version = ">= 1.10.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.30"
    }
  }
  backend "s3" {}
}

provider "aws" {
  region = var.region
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_partition" "current" {}


locals {
  logging_bucket_name = "${var.tower}-${var.environment}-terraform-${data.aws_caller_identity.current.id}-logs"
  state_bucket_name   = "${var.tower}-${var.environment}-terraform-${data.aws_caller_identity.current.id}"
  common_tags = {
    tower                = var.tower
    Environment          = var.environment
    CostCentre           = var.CostCentre
    region               = var.region
    ManagedBy            = "terraform"
    GitHubRepository     = var.github_tags.github_repository
    GitHubSourceURL      = var.github_tags.source_url
    GitHubWorkflowRunURL = var.github_tags.workflow_run_url
    GitHubActor          = var.github_tags.actor
    GitHubCreatedAt      = var.github_tags.created_at
  }
}

# ----------------------------------------------------------------------------
# S3 access logging bucket that receives logs from the Terraform state bucket
# ----------------------------------------------------------------------------
resource "aws_s3_bucket" "logging" {
  bucket        = local.logging_bucket_name
  force_destroy = false
  lifecycle {
    prevent_destroy = true
  }
  tags = merge(local.common_tags,
    {
      Name    = local.logging_bucket_name
      Purpose = "terraform-state-bucket-access-logs"
    }
  )
}
resource "aws_s3_bucket_ownership_controls" "logging" {
  bucket = aws_s3_bucket.logging.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}
resource "aws_s3_bucket_public_access_block" "logging" {
  bucket                  = aws_s3_bucket.logging.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
resource "aws_s3_bucket_versioning" "logging" {
  bucket = aws_s3_bucket.logging.id
  versioning_configuration {
    status = "Enabled"
  }
}
resource "aws_s3_bucket_server_side_encryption_configuration" "logging" {
  bucket = aws_s3_bucket.logging.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.enable_kms ? "aws:kms" : "AES256"
      kms_master_key_id = var.enable_kms ? var.kms_key_arn : null
    }
  }
}

# --------------------------------------------------
# Terraform State Bucket 
# --------------------------------------------------
resource "aws_s3_bucket" "state" {
  bucket        = local.state_bucket_name
  force_destroy = false
  lifecycle {
    prevent_destroy = true
  }
  tags = merge(local.common_tags,
    {
      Name    = local.state_bucket_name
      Purpose = "terraform-state-bucket"
    }
  )
}
resource "aws_s3_bucket_ownership_controls" "state" {
  bucket = aws_s3_bucket.state.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}
resource "aws_s3_bucket_public_access_block" "state" {
  bucket                  = aws_s3_bucket.state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id
  versioning_configuration {
    status = "Enabled"
  }
}
resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.enable_kms ? "aws:kms" : "AES256"
      kms_master_key_id = var.enable_kms ? var.kms_key_arn : null
    }
  }
}
# Enable Access Logging (State → Logging)
resource "aws_s3_bucket_logging" "state" {
  bucket        = aws_s3_bucket.state.id
  target_bucket = aws_s3_bucket.logging.id
  target_prefix = "terraform-state-access-logs/"
}
# LIFECYCLE RULE (abort multipart uploads)
resource "aws_s3_bucket_lifecycle_configuration" "state" {
  bucket = aws_s3_bucket.state.id
  # Abort failed multipart uploads
  rule {
    id     = "abort-incomplete-multipart"
    status = "Enabled"
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  # Keep only recent Terraform state history
  rule {
    id     = "expire-noncurrent-after-365-days"
    status = "Enabled"
    noncurrent_version_expiration {
      noncurrent_days           = 365
      newer_noncurrent_versions = 15 # AWS will never delete the 15 most recent noncurrent versions, even if they’re older than 365 days.
    }
  }
}

# --------------------------------------------------
# Bucket Policy for Terraform State Bucket
# --------------------------------------------------
data "aws_iam_policy_document" "state_bucket_policy" {
  # Allow account root to list bucket & get location
  statement {
    sid    = "AllowAccountRootReadOnly"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.id}:root"]
    }
    actions = [
      "s3:ListBucket",
      "s3:GetBucketLocation",
      "s3:GetBucketVersioning"
    ]
    resources = [aws_s3_bucket.state.arn]
  }
  # Allow GitHub OIDC role full state object access
  statement {
    sid    = "AllowOIDCRoleStateAccess"
    effect = "Allow"
    principals {
      type = "AWS"
      identifiers = [
        "arn:aws:iam::${data.aws_caller_identity.current.id}:role/iamr-${var.tower}-${var.environment}-deploy"
      ]
    }
    actions = [
      "s3:ListBucket",
      "s3:GetBucketLocation",
      "s3:GetBucketVersioning",
      "s3:GetObject",
      "s3:PutObject",
      "s3:AbortMultipartUpload",
      "s3:ListMultipartUploadParts"
    ]
    resources = [
      aws_s3_bucket.state.arn,
      "${aws_s3_bucket.state.arn}/*"
    ]
  }
  # EXPLICIT DENY – protect Terraform state forever from deletion
  statement {
    sid    = "DenyTerraformStateBucketDeletion"
    effect = "Deny"
    principals {
      type = "AWS"
      identifiers = [
        "arn:aws:iam::${data.aws_caller_identity.current.id}:root",
        "arn:aws:iam::${data.aws_caller_identity.current.id}:role/iamr-${var.tower}-${var.environment}-deploy"
      ]
    }
    actions = [
      "s3:DeleteBucket"
    ]
    resources = [aws_s3_bucket.state.arn]
  }
}

resource "aws_s3_bucket_policy" "state" {
  bucket = aws_s3_bucket.state.id
  policy = data.aws_iam_policy_document.state_bucket_policy.json
}
```

---

### variables.tf
```hcl
# This file defines all input variables used by the module.
# These variables allow users to customize and control how the AWS resources are created.
# Each variable serves as an input that lets callers adjust naming, behavior, and configuration of the module.

variable "tower" {
  description = "workload tower"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}
variable "CostCentre" {
  description = "Cost Centre tag value to apply to resources created in this account"
  type        = string
}
variable "enable_kms" {
  description = "Enable KMS encryption for S3 buckets"
  type        = bool
  default     = false
}
variable "kms_key_arn" {
  type    = string
  default = null
  validation {
    condition     = !(var.enable_kms && var.kms_key_arn == null)
    error_message = "kms_key_arn must be set when enable_kms=true"
  }
}

variable "github_tags" {
  description = "Github metadata for tagging"
  type = object({
    github_repository = string
    source_url        = string
    workflow_run_url  = string
    actor             = string
    created_at        = string
  })
}

variable "tags" {
  description = "Tags for s3 bucket"
  type        = map(string)
  default     = {}
}

```

---

### outputs.tf

```hcl
output "state_bucket_name" {
  value = aws_s3_bucket.state.id
}

output "logging_bucket_name" {
  value = aws_s3_bucket.logging.id
}

output "state_bucket_arn" {
  value = aws_s3_bucket.state.arn
}

output "logging_bucket_arn" {
  value = aws_s3_bucket.logging.arn
}
```

---

## Enterprise Best Practices

- Bootstrap exactly once per account
- Use approval gate (GH environment) for deployment
- Centralized account mapping
- No static credentials
- Strong tagging and audit controls

---

## Out of Scope / Non-Goals

This bootstrap module intentionally does **not** provision:

- Application infrastructure (EC2, EKS, RDS, etc.)
- Networking (VPC, subnets, gateways etc)
- IAM users or long-lived credentials
- CI/CD pipelines beyond initial bootstrap
- Monitoring or security tooling (GuardDuty, Config, etc.)

These concerns are handled by **downstream, environment-specific Terraform modules**.

---

## Security Considerations

- No long-lived credentials
- Least-privilege IAM
- Encrypted, versioned state
- Auditable session tagging
- Separation of duties via approval gates
- Terraform state bucket deletion is explicitly denied, including for the account root user, to prevent accidental or irreversible loss of infrastructure state.

---

## Summary

This AWS Account Bootstrap module establishes a **secure**, **scalable**, and **enterprise-ready foundation** for Terraform-driven infrastructure across AWS Organizations.

It is the **recommended enterprise pattern** for large-scale AWS + GitHub environments.