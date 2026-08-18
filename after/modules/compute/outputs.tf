output "app_sg_id" {
  description = "Security group ID of the app tier"
  value       = aws_security_group.app.id
}
