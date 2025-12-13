# Terraform AWS Module Blueprint

A standardized, production-grade template for building reusable Terraform AWS modules.  
Use this blueprint to ensure **consistent structure**, **naming**, **versioning**, and **CI automation** across all module repositories in your organization.

---

## Table of Contents

1. [Overview](#overview)  
2. [Why Use This Blueprint?](#why-use-this-blueprint)  
3. [Naming Convention](#naming-convention)  
4. [Repository Structure](#repository-structure)  
   - [File Descriptions](#file-descriptions)  
5. [Creating a New Module From This Template](#creating-a-new-module-from-this-template)  
6. [Setting Up Your Environment](#setting-up-your-environment)  
7. [Versioning & Initial Setup](#versioning--initial-setup)  
8. [Automatic Version Bumping (CI)](#automatic-version-bumping-ci)  
9. [Examples](#examples)  
10. [Outputs](#outputs)  
11. [Notes & Best Practices](#notes--best-practices)  
12. [PR Checklist](#pr-checklist) -- **To be discussed**

---

## Overview

The **Terraform AWS Module Blueprint** provides a `standardized template` for building reusable Terraform modules for AWS services. It is designed to `simplify Infrastructure-as-Code workflows`, ensure `consistency across projects`, and accelerate module development by offering a `structured, best-practice approach` for creating and managing Terraform modules. 

This template ensures every module follows the same:
- folder structure  
- naming patterns  
- variable patterns 
- versioning standards 
- GitHub Actions CI  
- example layout  
- documentation style  

Using this blueprint ensures every module is **predictable**, **reusable**, **easy to maintain**, **CI-ready** and **maintainable** from day one.

---

## Why Use This Blueprint?

### Fast & Consistent  
Use **Use this template** to instantly create a new Terraform module with a complete, production-ready structure. — **no manual copying**.

### Clean Git History  
New modules begin with a single initial commit.

### Standardization  
All modules follow the same layout, naming, CI workflow, documentation style, and example layout.

### Automated Versioning  
- GitHub Actions bumps module versions automatically based on PR and commit messages.
- **automatic semantic version tagging**

### Scalable  
This template evolves over time; future modules automatically inherit improvements.

---

## Naming Convention

To maintain consistency across all Terraform modules, follow these rules for all Terraform AWS modules:

| Component | Pattern | Example |
|----------|--------|---------|
| Repository name | `tf-aws-module-<service>` | `tf-aws-module-s3` |
| Branch | `<type>/<short-description>` | `feat/versioning-support` |
| Feature Branch | `feat/<short-description>` | `feat/add-logging` |
| Fix Branch | `fix/<short-description>` | `fix/incorrect-output` |
| Git Tags | `vX.Y.Z` | `v1.0.2` |
| Version File | `X.Y.Z` | `1.0.2` |

Examples:
- `tf-aws-module-blueprint`  
- `tf-aws-module-ec2`
- `tf-aws-module-networking`

---

## Repository Structure

```
tf-aws-module-<service>/
├── .gitignore
├── .github/
│   └── workflows/
│       └── repository-auto-versioning.yml
├── modules/
├── main.tf
├── variables.tf
├── outputs.tf
├── README.md
├── CHANGELOG.md
├── version
├── examples/
│   └── example-usage/
│       ├── environment/
│       │   ├── dev.tfvars
│       │   ├── sit.tfvars
│       │   ├── ppe.tfvars
│       │   └── prod.tfvars
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       └── README.md
```

### File Descriptions

- **`.gitignore`** 
  Defines files and directories to exclude from version control, such as Terraform state files, .terraform/ directories, local secrets and IDE-specific configurations. Essential for standardized module versioning across the org.

- **`.github/workflows/repository-auto-versioning.yml`**  
  Repo-level workflow that:
  - triggers on PR merge,  
  - checks for `[skip ci]` in PR title/body/commits 
  - calls the shared composite action for version bumping.
  - Automatic version bumps when PRs are merged.
  - updates CHANGELOG.md

- **`modules/`**  
  Holds optional nested modules for related resources (e.g., IAM roles, users, and policies) to promote modular design.

- **`main.tf`**  
  The main Terraform configuration file that defines the AWS infrastructure resources.

- **`variables.tf`**  
  Contains the input variables that allow customization of the module’s behavior and resource properties.

- **`outputs.tf`**  
  Specifies output values that expose useful information about the resources created by the module.

- **`CHANGELOG.md`**  
  Auto-prepended by CI to record version history. Maintains a history of changes, enhancements, and fixes for the module across versions. It add Release notes per SemVer.

- **`README.md`**
  Documentation explaining the module's usage and configuration.

- **`version`**  
  Stores current module version in **X.Y.Z** format (no `v`). This file is **automatically updated** by CI — do not edit after initial scaffolding. CI updates this file automatically after each release.

- **`examples/`**  
  Shows how to consume the module with environment-specific `.tfvars`. It contains example usages of the module to demonstrate how it can be integrated into a Terraform project. Multiple folders should be created to cover different use cases and scenarios.

---

## Creating a New Module From This Template

1. **Enable Template Mode** *(blueprint repo only)*
   - `GitHub → Repository → Settings → Template repository → Enable`

   > ⚠️ New module repositories **do not** need template mode.

2. **Create a new module repository**
   - Click **Use this template** → Create repo
   - Name it:
     ```
     tf-aws-module-<service>
     ```

3. **Clone the repository** to your laptop/workstation
      ```bash
      git clone https://github.com/your-org/tf-aws-module-<service>.git
      cd tf-aws-module-<service>
      ```

4. **Create feature branch**
      ```bash
      git checkout -b feat/initial-module-implementation
      ```

5. **Reset initial version**  
   New repos inherit whatever version existed in the blueprint.  
   Standardize it:

5. **Customize Your Module**
   - Update `main.tf`, `variables.tf`, `outputs.tf` **based on new terraform module resource type**
   - Update `examples/example-usage`
   - Update README with module-specific details
   - set module version in **version** file to `0.0.0`
   - Remove the content of **CHANGELOG.md**. Post PR merge, recversion history.

6. **Commit & Push**
   ```bash
   git add .
   git commit -m "feat: initial module implementation"
   git push origin feat/initial-implementation
   ```

7. Open a Pull Request → Merge → CI will handle versioning.

8. After merge → CI bumps version automatically.

---

## Setting Up Your Environment

- Terraform ≥ 1.1.x
- AWS credentials configured (AWS CLI / IAM Role / SSO)
- Confirm linting locally:

```bash
terraform fmt -recursive
terraform validate
```

- `terraform init` / `plan` run locally before raising PR

To test example:

```bash
terraform -chdir=examples/example-usage init
terraform -chdir=examples/example-usage plan
```

---

## Versioning & Initial Setup

This blueprint uses **strict semantic versioning (MAJOR.MINOR.PATCH) ** driven by PR commit messages.

### Version File (`version`)
- Stored as **X.Y.Z**  
- Updated automatically by CI after merges  
- Should always reflect latest pushed tag  
- Must contain only **0.0.0** at initial setup for new module. The CI pipeline will update this file upon each release.

```
0.0.0
```

### Git Tags
- CI creates tags using format:  
  ```
  vX.Y.Z
  ```

---

## Automatic Version Bumping (CI)

When a PR is merged to `main`, The included GitHub Actions CI performs the following:

### 1. Skip-CI Check
If PR title, PR body, or any commit message contains:

```
[skip ci]
skip-ci
skip ci
skip_ci
```

→ CI does **not** bump the version or create a tag.

---

### 2. Version Bump Logic (Semantic Versioning)

The workflow scans:

- PR **title**  
- PR **body**  
- **every** commit message inside the PR  

Bump rules:

| Pattern | Meaning | Action |
|---------|---------|--------|
| `feat:` OR `feat(scope):` | New feature | **MINOR bump** |
| `fix:` | Bug fix | **PATCH bump** |
| `BREAKING CHANGE:` or `feat!:` or `refactor!:`, commit subject containing `!` | Breaking change | **MAJOR bump** |
| Other (chore, docs, refactor without `!`, style, CI updates) | Maintenance | **PATCH bump** |

### Precedence rule
If multiple commits match different rules:

```
MAJOR > MINOR > PATCH
```

### Examples

| Current | Commit Message | Result |
|---------|----------------|--------|
| `0.1.3` | `feat: add bucket policy` | `0.2.0` |
| `0.2.0` | `fix: correct validation` | `0.2.1` |
| `0.3.0` | `BREAKING CHANGE: remove input variable` | `1.0.0` |
| `1.1.0` | `chore: update readme` | `1.1.1` |
| `1.1.1` | mix of `feat:` + `fix:` + `docs:` | `1.2.0` (because MINOR > PATCH) |

---

### 3. Tag Creation

CI does the following:

```bash
git commit -m "chore(release): vX.Y.Z [skip ci]"
git tag -a vX.Y.Z -m "Version X.Y.Z"
git push origin main
git push origin vX.Y.Z
```

- No GitHub Release objects are created — **only git tags**.
- Only annotated tags + updated CHANGELOG + version file

---

## Examples

Examples are located in:

```
examples/example-usage/
```

Run:

```bash
terraform -chdir=examples/example-usage init
terraform -chdir=examples/example-usage plan
```

---

## Outputs

Modules should expose only essential outputs — e.g.:

- ARNs  
- IDs  
- Names  
- Endpoints
- Sensitive values marked appropriately using `sensitive = true`

---

## Notes & Best Practices

- Single responsibility: each module should manage one AWS resource.  
- Do not embed providers inside modules; inject providers at application level.
- Never hardcode credentials.  
- Avoid hardcoding AWS regions
- Enable secure defaults: private access, encryption.  
- Validate inputs using `validation` blocks.  
- Tags should be supplied by the **application-level root module**, not the module itself  
- CI enforces:
  - `terraform init -backend=false -input=false`
  - `terraform fmt -check -recursive`
  - `terraform validate`

---

## PR Checklist

- [ ] `terraform fmt` applied  
- [ ] `terraform validate` passed  
- [ ] Example plan executed in CI  - **For application specific repository**
- [ ] No secrets committed  
- [ ] README updated (if needed)  
- [ ] CHANGELOG updated (if needed)  
- [ ] Commit messages follow required patterns (`feat:`, `fix:`, `chore:` etc.)  
- [ ] Breaking changes explicitly documented (`!` or `BREAKING CHANGE:`) if applicable  

---