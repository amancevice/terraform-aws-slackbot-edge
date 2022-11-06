output "distribution" {
  description = "CloudFront distribution"
  value       = aws_cloudfront_distribution.distribution
}

output "event_bus" {
  description = "EventBridge bus"
  value       = aws_cloudwatch_event_bus.bus
}

output "secret" {
  description = "SecretsManager secret container"
  value       = aws_secretsmanager_secret.secret
}
