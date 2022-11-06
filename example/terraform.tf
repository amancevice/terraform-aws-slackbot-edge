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

    local = {
      source  = "hashicorp/local"
      version = "~> 2.2"
    }
  }
}

###########
#   AWS   #
###########

provider "aws" {
  region = "us-east-1"
}

provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

provider "aws" {
  alias  = "us_west_2"
  region = "us-west-2"
}

provider "aws" {
  alias  = "eu_west_2"
  region = "eu-west-2"
}

#####################
#   SLACKBOT EDGE   #
#####################

locals {
  edge_domain   = "slack.${var.domain}"
  origin_domain = "slack-api.${var.domain}"
}

module "slackbot-edge" {
  providers                       = { aws.us_east_1 = aws.us_east_1 }
  source                          = "./.."
  distribution_aliases            = [local.edge_domain]
  distribution_description        = local.edge_domain
  distribution_origin_domain_name = local.origin_domain
  edge_function_name              = "slackbot-edge"
  event_bus_name                  = "slackbot"
  secret_hash                     = sha256(aws_secretsmanager_secret_version.secret.secret_string)
  secret_name                     = "slackbot"
  zone_id                         = data.aws_route53_zone.zone.id

  edge_function_permissions = [{
    name = "ApiGateway"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [{
        Sid      = "ExecuteApi"
        Effect   = "Allow"
        Action   = "execute-api:Invoke"
        Resource = "*" # "${data.aws_apigatewayv2_api.origin.execution_arn}/*/*/*"
      }]
    })
  }]

  distribution_viewer_certificate = {
    acm_certificate_arn      = data.aws_acm_certificate.us_east_1.arn
    minimum_protocol_version = "TLSv1.2_2021"
    ssl_support_method       = "sni-only"
  }
}

# output "healthcheck" { value = "https://${local.edge_domain}/health" }

#############################
#   HTTP API :: US-EAST-1   #
#############################

module "api-us-east-1" {
  providers             = { aws = aws.us_east_1 }
  source                = "./rest-api"
  api_name              = "slackbot"
  api_certificate_arn   = data.aws_acm_certificate.us_east_1.arn
  api_domain            = local.origin_domain
  api_zone_id           = data.aws_route53_zone.zone.id
  default_function_name = "slackbot-default"
}

module "api-us-west-2" {
  providers             = { aws = aws.us_west_2 }
  source                = "./rest-api"
  api_name              = "slackbot"
  api_certificate_arn   = data.aws_acm_certificate.us_west_2.arn
  api_domain            = local.origin_domain
  api_zone_id           = data.aws_route53_zone.zone.id
  default_function_name = "slackbot-default"
}

module "api-eu-west-2" {
  providers             = { aws = aws.eu_west_2 }
  source                = "./rest-api"
  api_name              = "slackbot"
  api_certificate_arn   = data.aws_acm_certificate.eu_west_2.arn
  api_domain            = local.origin_domain
  api_zone_id           = data.aws_route53_zone.zone.id
  default_function_name = "slackbot-default"
}

###########
#   DNS   #
###########

variable "domain" { type = string }

data "aws_acm_certificate" "us_east_1" {
  provider = aws.us_east_1
  domain   = var.domain
  types    = ["AMAZON_ISSUED"]
}

data "aws_acm_certificate" "us_west_2" {
  provider = aws.us_west_2
  domain   = var.domain
  types    = ["AMAZON_ISSUED"]
}

data "aws_acm_certificate" "eu_west_2" {
  provider = aws.eu_west_2
  domain   = var.domain
  types    = ["AMAZON_ISSUED"]
}

data "aws_route53_zone" "zone" {
  name = "${var.domain}."
}

##############
#   SECRET   #
##############

variable "secret" {
  type = object({
    SLACK_OAUTH_CLIENT_ID     = string
    SLACK_OAUTH_CLIENT_SECRET = string
    SLACK_OAUTH_SCOPE         = string
    SLACK_OAUTH_USER_SCOPE    = string
    SLACK_OAUTH_ERROR_URI     = string
    SLACK_OAUTH_REDIRECT_URI  = string
    SLACK_OAUTH_SUCCESS_URI   = string
    SLACK_SIGNING_SECRET      = string
    SLACK_SIGNING_VERSION     = string
  })
}

resource "aws_secretsmanager_secret_version" "secret" {
  provider      = aws.us_east_1
  secret_id     = module.slackbot-edge.secret.id
  secret_string = jsonencode(var.secret)
}
