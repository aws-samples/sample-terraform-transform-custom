variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "public_subnets" {
  description = "Map of public subnets keyed by AZ suffix"
  type        = map(object({ cidr = string, az = string }))
}

variable "private_subnets" {
  description = "Map of private subnets keyed by AZ suffix"
  type        = map(object({ cidr = string, az = string }))
}

variable "project" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name for tags"
  type        = string
}
