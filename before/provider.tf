# NOTE (before-state): provider is intentionally UNPINNED and the region is
# hardcoded here. There is no `terraform { required_providers { ... } }` block
# and no backend configuration, so Terraform downloads whatever AWS provider
# version is latest at init time and stores state locally. This is one of the
# deliberate "smells" this demo modernizes.
provider "aws" {
  region = "us-east-1"
}
