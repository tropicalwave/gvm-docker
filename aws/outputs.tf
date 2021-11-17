output "public_connection_string" {
  description = "Login to EC2 instance"
  value       = "ssh -i ${module.ssh-key.key_name}.pem rocky@${module.ec2.public_ip} -L 4443:localhost:4443"
}
