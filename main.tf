#################
#   TERRAFORM   #
#################

terraform {
  required_version = "~> 1.0"

  required_providers {
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }

    aws = {
      source                = "hashicorp/aws"
      version               = "~> 4.0"
      configuration_aliases = [aws.us_east_1]
    }

    local = {
      source  = "hashicorp/local"
      version = "~> 2.2"
    }
  }
}

############
#   DATA   #
############

data "aws_region" "current" {}

#######################
#   SECRET CONTAINER  #
#######################

resource "aws_secretsmanager_secret" "secret" {
  provider = aws.us_east_1
  name     = var.secret_name
}

#######################
#   EVENTBRIDGE BUS   #
#######################

resource "aws_cloudwatch_event_bus" "bus" {
  name = var.event_bus_name
}

#####################
#   EDGE FUNCTION   #
#####################

resource "local_file" "env" {
  filename        = "${path.module}/functions/edge/dist/app/env.py"
  file_permission = "0644"

  content = templatefile("${path.module}/functions/edge/dist/app/env.py.tpl", {
    ApiHost        = var.distribution_origin_domain_name
    EventBusName   = aws_cloudwatch_event_bus.bus.name
    EventBusRegion = data.aws_region.current.name
    SecretHash     = var.secret_hash
    SecretId       = aws_secretsmanager_secret.secret.id
    SecretRegion   = "us-east-1"
  })
}

data "archive_file" "edge" {
  depends_on  = [local_file.env]
  source_dir  = "${path.module}/functions/edge/dist"
  output_path = "${path.module}/functions/edge/package.zip"
  type        = "zip"
}

resource "aws_iam_role" "edge" {
  name = var.edge_function_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AssumeLambdaEdge"
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = ["lambda.amazonaws.com", "edgelambda.amazonaws.com"] }
    }]
  })

  inline_policy {
    name = "EventBridge"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [{
        Sid      = "EventBridge"
        Effect   = "Allow"
        Action   = "events:PutEvents"
        Resource = aws_cloudwatch_event_bus.bus.arn
      }]
    })
  }

  inline_policy {
    name = "Logs"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [{
        Sid      = "Logs"
        Effect   = "Allow"
        Action   = "logs:*"
        Resource = "*"
    }] })
  }

  inline_policy {
    name = "SecretsManager"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [{
        Sid      = "SecretsManager"
        Effect   = "Allow"
        Action   = "secretsmanager:GetSecretValue"
        Resource = aws_secretsmanager_secret.secret.arn
        }
      ]
    })
  }

  dynamic "inline_policy" {
    for_each = var.edge_function_permissions

    content {
      name   = inline_policy.value.name
      policy = inline_policy.value.policy
    }
  }
}

resource "aws_lambda_function" "edge" {
  provider         = aws.us_east_1
  architectures    = ["x86_64"]
  description      = var.edge_function_description
  filename         = data.archive_file.edge.output_path
  function_name    = var.edge_function_name
  handler          = "index.handler"
  memory_size      = 512
  publish          = true
  role             = aws_iam_role.edge.arn
  runtime          = "python3.9"
  source_code_hash = data.archive_file.edge.output_base64sha256
}

##################
#   CLOUDFRONT   #
##################

resource "aws_cloudfront_distribution" "distribution" {
  aliases         = var.distribution_aliases
  comment         = var.distribution_description
  enabled         = var.distribution_enabled
  http_version    = var.distribution_http_version
  is_ipv6_enabled = var.distribution_is_ipv6_enabled
  price_class     = var.distribution_price_class

  default_cache_behavior {
    allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true
    default_ttl            = 0
    max_ttl                = 0
    min_ttl                = 0
    target_origin_id       = var.distribution_origin_domain_name
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = true
      headers      = ["x-slack-request-timestamp", "x-slack-signature"]

      cookies { forward = "none" }
    }

    lambda_function_association {
      event_type   = "origin-request"
      include_body = true
      lambda_arn   = aws_lambda_function.edge.qualified_arn
    }
  }

  dynamic "logging_config" {
    for_each = var.distribution_logging_configurations

    content {
      bucket          = logging_config.value.bucket
      prefix          = logging_config.value.prefix
      include_cookies = logging_config.value.include_cookies
    }
  }

  origin {
    domain_name = var.distribution_origin_domain_name
    origin_id   = var.distribution_origin_domain_name

    custom_origin_config {
      http_port                = 80
      https_port               = 443
      origin_keepalive_timeout = 5
      origin_protocol_policy   = "https-only"
      origin_read_timeout      = 30
      origin_ssl_protocols     = ["TLSv1.2"]
    }
  }

  restrictions {
    geo_restriction {
      locations        = var.distribution_restrictions_locations
      restriction_type = var.distribution_restrictions_type
    }
  }

  viewer_certificate {
    acm_certificate_arn            = var.distribution_viewer_certificate.acm_certificate_arn
    cloudfront_default_certificate = var.distribution_viewer_certificate.cloudfront_default_certificate
    iam_certificate_id             = var.distribution_viewer_certificate.iam_certificate_id
    minimum_protocol_version       = var.distribution_viewer_certificate.minimum_protocol_version
    ssl_support_method             = var.distribution_viewer_certificate.ssl_support_method
  }
}

resource "aws_route53_record" "records" {
  for_each = toset(var.distribution_aliases)
  name     = each.value
  type     = "A"
  zone_id  = var.zone_id

  alias {
    zone_id                = aws_cloudfront_distribution.distribution.hosted_zone_id
    name                   = aws_cloudfront_distribution.distribution.domain_name
    evaluate_target_health = false
  }
}
