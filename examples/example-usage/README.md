# Example Usage: Terraform AWS Module Blueprint

This directory provides an example of how to use the **Terraform AWS Module Blueprint** to deploy an AWS S3 bucket using the standardized module structure. It demonstrates how to structure your configuration, pass variables, and verify changes before merging to the `main` branch.

---

## Overview

The example configuration imports the module from the parent directory and supplies the required input variables. Its purpose is to guide you on how to integrate the module into real Terraform projects in a consistent and reusable way.

---

## Directory Structure

```
├── examples
│   └── example-usage
│       ├── environment
│       │   ├── dev.tfvars
│       │   ├── ppe.tfvars
│       │   ├── prod.tfvars
│       │   └── sit.tfvars
│       ├── main.tf
│       ├── outputs.tf
│       └── variables.tf
```

### File Descriptions

- **`main.tf`**  
  References the AWS module from the parent directory and passes the required input variables for this example.

- **`variables.tf`**  
  Defines all input variables used by this example configuration, helping to maintain clarity and consistency.

- **`outputs.tf`**  
  Exposes key resource attributes returned by the example, such as S3 bucket details.

- **`environment/*.tfvars`**  
  Contains environment-specific values (e.g., dev, sit, ppe, prod).  
  These files allow you to test the same configuration across multiple environments.

---

## Prerequisites

Before using this example, ensure you have:

- A valid AWS account with permissions to create S3 resources.
- Terraform installed locally (`terraform >= 1.0.0` recommended).
- AWS credentials configured via environment variables, AWS CLI, or shared credentials file.

---

## How to Use This Example

This example illustrates the recommended workflow for validating your Terraform changes **before merging to main**.

Follow the steps below:

---

### 1. Review and Customize Input Variables

Update values inside:

```
environment/<ENVIRONMENT>.tfvars
```

Common inputs you may update:

- `app_name`
- `environment`
- `owner`
- Any module-specific inputs from `variables.tf`

---

### 2. Initialize Terraform

From inside the `examples/example-usage` directory, run:

```bash
terraform init
```

This downloads providers and initializes the working directory.

---

### 3. Run Terraform Plan

Generate an execution plan to preview changes:

```bash
terraform plan -var-file="environment/<ENVIRONMENT>.tfvars"
```

Example:

```bash
terraform plan -var-file="environment/dev.tfvars"
```

---

### 4. Apply the Configuration

To deploy the resources:

```bash
terraform apply -var-file="environment/<ENVIRONMENT>.tfvars"
```

Approve the plan by typing `yes`.  
Terraform will create the S3 bucket and any supporting resources defined in the module.

---

### 5. Review Outputs

After the apply is complete, Terraform will show outputs such as:

- `bucket_name`
- `bucket_arn`

These values come from the module’s `outputs.tf`.

---

### 6. Cleanup Resources

To destroy resources created by this example:

```bash
terraform destroy -var-file="environment/<ENVIRONMENT>.tfvars"
```

Confirm with `yes` when prompted.

---

## Additional Notes

- This example demonstrates **module versioning best practices**.  
  Ensure that your Git commit messages follow the defined conventions so that GitHub Actions can correctly auto-bump module versions.

- For contribution guidelines, refer back to the main repository's `README.md`.

- If you encounter issues, please:
  - Open an issue in the main repository  
  - Or contact the Terraform IMS channel on MS Teams  

---