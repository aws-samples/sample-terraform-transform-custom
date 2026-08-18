variable "vpc_id" {
  description = "VPC ID where compute resources are created"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for the ECS service"
  type        = list(string)
}

variable "alb_sg_id" {
  description = "Security group ID of the ALB (for app SG ingress)"
  type        = string
}

variable "target_group_arn" {
  description = "ARN of the ALB target group"
  type        = string
}

variable "project" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name for tags"
  type        = string
}

variable "region" {
  description = "AWS region for CloudWatch logs"
  type        = string
}

variable "container_image" {
  description = "Container image for the ECS task"
  type        = string
}

variable "container_port" {
  description = "Port the container listens on"
  type        = number
}

variable "task_cpu" {
  description = "CPU units for the ECS task"
  type        = string
}

variable "task_memory" {
  description = "Memory (MiB) for the ECS task"
  type        = string
}

variable "desired_count" {
  description = "Desired number of ECS tasks"
  type        = number
}
