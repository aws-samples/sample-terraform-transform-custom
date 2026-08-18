# Refactoring Patterns Catalog

Concrete before/after patterns for the structural and hygiene improvements this
transformation applies. Apply the ones that fit; preserve all values so the plan
stays a no-op.

## Pattern 1: Hardcoded literal → typed variable

**Before**

```hcl
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}
```

**After**

```hcl
variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"   # preserve the existing value
}

resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
}
```

Keep the `default` equal to the original literal so nothing changes. Add `type` and
`description` always. Use rich types (`map`, `object`, `list`) for structured data.

## Pattern 2: Copy-pasted blocks → `for_each`

**Before** (four hand-written subnets)

```hcl
resource "aws_subnet" "public_a"  { cidr_block = "10.0.0.0/24"  availability_zone = "us-east-1a" map_public_ip_on_launch = true ... }
resource "aws_subnet" "public_b"  { cidr_block = "10.0.1.0/24"  availability_zone = "us-east-1b" map_public_ip_on_launch = true ... }
resource "aws_subnet" "private_a" { cidr_block = "10.0.10.0/24" availability_zone = "us-east-1a" ... }
resource "aws_subnet" "private_b" { cidr_block = "10.0.11.0/24" availability_zone = "us-east-1b" ... }
```

**After**

```hcl
variable "public_subnets" {
  type = map(object({ cidr = string, az = string }))
  default = {
    a = { cidr = "10.0.0.0/24", az = "us-east-1a" }
    b = { cidr = "10.0.1.0/24", az = "us-east-1b" }
  }
}

resource "aws_subnet" "public" {
  for_each                = var.public_subnets
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = true
  vpc_id                  = aws_vpc.main.id
}
```

Add a `moved` block for each original resource (see `moved-blocks.md`). The keys
(`a`, `b`) must match the keys used in the `moved` blocks' `to` addresses.

## Pattern 3: Repeated inline tags → provider `default_tags`

**Before** (every resource repeats the same tags)

```hcl
resource "aws_vpc" "main" {
  tags = { Name = "demo-vpc", Environment = "dev", Project = "demo", ManagedBy = "terraform" }
}
```

**After**

```hcl
provider "aws" {
  region = var.region
  default_tags {
    tags = {
      Environment = var.environment
      Project     = var.project
      ManagedBy   = "terraform"
    }
  }
}

resource "aws_vpc" "main" {
  tags = { Name = "demo-vpc" }   # keep only the resource-specific Name
}
```

**Caution:** `default_tags` merges with per-resource `tags`. The *effective* tag set
on each resource must be identical to before, or `terraform plan` will show tag
changes. Verify with a plan. Tags that are not identical across all resources must
stay inline.

## Pattern 4: Pin the provider

**Before** (no version constraint anywhere)

```hcl
provider "aws" {
  region = "us-east-1"
}
```

**After**

```hcl
terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"   # match the currently resolved major version
    }
  }
}
```

Pin to a constraint that matches the provider version already in
`.terraform.lock.hcl` so the plan does not change.

## Pattern 5: Externalize plaintext secrets

**Before**

```hcl
resource "aws_db_instance" "main" {
  password = "REDACTED-PLAINTEXT-PASSWORD" # anti-pattern: secret in the .tf file
}
```

**After**

```hcl
variable "db_password" {
  description = "Master password for the RDS instance"
  type        = string
  sensitive   = true
}

resource "aws_db_instance" "main" {
  password = var.db_password
}
```

Provide the value via a `.tfvars` file (gitignored), environment variable
(`TF_VAR_db_password`), or a secrets manager data source. **Do not change the
value** — the same password must be supplied so the plan stays a no-op. For a true
production improvement, generate a new secret in AWS Secrets Manager and rotate, but
that is a value change and out of scope for a no-op-preserving refactor.

## Pattern 6: Consistent naming and locals

Introduce a `local` for repeated name prefixes to remove magic strings:

```hcl
locals {
  name_prefix = "${var.project}-${var.environment}"
}
```

Use it only where it does not change the resulting resource names/values.

## Reminder

Every structural change above that alters a resource address requires a `moved`
block. The acceptance criterion for the whole transformation is an unchanged
`terraform plan` ("No changes").
