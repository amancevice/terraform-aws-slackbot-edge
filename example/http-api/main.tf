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
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

########################
#   DEFAULT FUNCTION   #
########################

data "archive_file" "default" {
  source_dir  = "${path.module}/functions/default/src"
  output_path = "${path.module}/functions/default/package.zip"
  type        = "zip"
}

resource "aws_iam_role" "default" {
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AssumeLambdaEdge"
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })

  inline_policy {
    name = "access"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [{
        Sid      = "Logs"
        Effect   = "Allow"
        Action   = "logs:*"
        Resource = "*"
      }]
    })
  }
}

resource "aws_lambda_function" "default" {
  architectures    = ["arm64"]
  description      = var.default_function_description
  filename         = data.archive_file.default.output_path
  function_name    = var.default_function_name
  handler          = "index.handler"
  role             = aws_iam_role.default.arn
  runtime          = "python3.9"
  source_code_hash = data.archive_file.default.output_base64sha256
}

resource "aws_lambda_permission" "default" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.default.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.api.execution_arn}/${aws_apigatewayv2_stage.default.name}/ANY/{default}"
}

resource "aws_cloudwatch_log_group" "default" {
  name              = "/aws/lambda/${aws_lambda_function.default.function_name}"
  retention_in_days = 14
}

################
#   HTTP API   #
################

resource "aws_apigatewayv2_api_mapping" "api" {
  api_id      = aws_apigatewayv2_api.api.id
  domain_name = aws_apigatewayv2_domain_name.api.id
  stage       = aws_apigatewayv2_stage.default.id
}

resource "aws_apigatewayv2_api" "api" {
  description   = var.api_description
  name          = var.api_name
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.api.id
  auto_deploy = true
  description = var.api_description
  name        = "$default"

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api.arn

    format = jsonencode({
      httpMethod              = "$context.httpMethod"
      integrationErrorMessage = "$context.integrationErrorMessage"
      ip                      = "$context.identity.sourceIp"
      path                    = "$context.path"
      protocol                = "$context.protocol"
      requestId               = "$context.requestId"
      requestTime             = "$context.requestTime"
      responseLength          = "$context.responseLength"
      routeKey                = "$context.routeKey"
      status                  = "$context.status"
    })
  }

  lifecycle { ignore_changes = [deployment_id] }
}

resource "aws_apigatewayv2_route" "default" {
  api_id             = aws_apigatewayv2_api.api.id
  authorization_type = "AWS_IAM"
  route_key          = "ANY /{default}"
  target             = "integrations/${aws_apigatewayv2_integration.default.id}"
}

resource "aws_apigatewayv2_integration" "default" {
  api_id                 = aws_apigatewayv2_api.api.id
  description            = var.api_description
  integration_method     = "POST"
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.default.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_cloudwatch_log_group" "api" {
  name              = "/aws/apigatewayv2/${aws_apigatewayv2_api.api.name}"
  retention_in_days = var.log_retention_in_days
}

###########
#   DNS   #
###########

data "aws_region" "current" {}

resource "aws_apigatewayv2_domain_name" "api" {
  domain_name = var.api_domain

  domain_name_configuration {
    certificate_arn = var.api_certificate_arn
    endpoint_type   = "REGIONAL"
    security_policy = "TLS_1_2"
  }
}

resource "aws_route53_record" "api" {
  name           = aws_apigatewayv2_domain_name.api.domain_name
  set_identifier = data.aws_region.current.name
  type           = "A"
  zone_id        = var.api_zone_id

  alias {
    name                   = aws_apigatewayv2_domain_name.api.domain_name_configuration[0].target_domain_name
    zone_id                = aws_apigatewayv2_domain_name.api.domain_name_configuration[0].hosted_zone_id
    evaluate_target_health = false
  }

  latency_routing_policy {
    region = data.aws_region.current.name
  }
}
