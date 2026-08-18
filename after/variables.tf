variable "region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name used in tags and resource naming"
  type        = string
  default     = "dev"
}

variable "project" {
  description = "Project name used in tags and resource naming"
  type        = string
  default     = "three-tier-demo"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnets" {
  description = "Map of public subnets keyed by availability zone suffix"
  type        = map(object({ cidr = string, az = string }))
  default = {
    a = { cidr = "10.0.0.0/24", az = "us-east-1a" }
    b = { cidr = "10.0.1.0/24", az = "us-east-1b" }
  }
}

variable "private_subnets" {
  description = "Map of private subnets keyed by availability zone suffix"
  type        = map(object({ cidr = string, az = string }))
  default = {
    a = { cidr = "10.0.10.0/24", az = "us-east-1a" }
    b = { cidr = "10.0.11.0/24", az = "us-east-1b" }
  }
}

variable "container_image" {
  description = "Container image for the ECS task"
  type        = string
  default     = "public.ecr.aws/nginx/nginx:1.27"
}

variable "container_port" {
  description = "Port the container listens on"
  type        = number
  default     = 80
}

variable "task_cpu" {
  description = "CPU units for the ECS task"
  type        = string
  default     = "256"
}

variable "task_memory" {
  description = "Memory (MiB) for the ECS task"
  type        = string
  default     = "512"
}

variable "desired_count" {
  description = "Desired number of ECS tasks"
  type        = number
  default     = 1
}

variable "db_engine_version" {
  description = "PostgreSQL engine version for RDS"
  type        = string
  default     = "16.4"
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  description = "Allocated storage in GB for RDS"
  type        = number
  default     = 20
}

variable "db_name" {
  description = "Name of the initial database"
  type        = string
  default     = "appdb"
}

variable "db_username" {
  description = "Master username for the RDS instance"
  type        = string
  default     = "appadmin"
}

variable "db_password" {
  description = "Master password for the RDS instance. No default, so the secret is never committed; provide it at runtime, e.g. export TF_VAR_db_password=... For a no-op plan the value must match what is already in state."
  type        = string
  sensitive   = true
}
