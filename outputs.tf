output "instance_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_eip.app.public_ip
}

output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.app.id
}

output "app_url" {
  description = "Application URL"
  value       = "http://${aws_eip.app.public_ip}:5000"
}

output "health_url" {
  description = "Health check endpoint"
  value       = "http://${aws_eip.app.public_ip}:5000/health"
}

output "ssh_command" {
  description = "SSH command to connect to the instance"
  value       = "ssh -i your-private-key.pem ec2-user@${aws_eip.app.public_ip}"
}
