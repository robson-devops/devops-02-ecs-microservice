output "state_bucket_name" {
  description = "Nome do bucket de state, passado ao terraform init do projeto via -backend-config"
  value       = aws_s3_bucket.state.id
}
