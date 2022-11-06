###################
#   EDGE LAMBDA   #
###################

variable "edge_function_description" {
  description = "Lambda@Edge Slack handler function description"
  type        = string
  default     = "Slackbot Lambda@Edge handler"
}

variable "edge_function_name" {
  description = "Lambda@Edge Slack handler function name"
  type        = string
}

variable "edge_function_permissions" {
  description = "Lambda@Edge IAM permissions"
  default     = []

  type = list(object({
    name   = string
    policy = string
  }))

}

#################
#   EVENT BUS   #
#################

variable "event_bus_name" {
  description = "EventBridge bus name"
  type        = string
}

##################
#   CLOUDFRONT   #
##################

variable "distribution_aliases" {
  description = "CloudFront distribution aliases"
  type        = list(string)
  default     = []
}

variable "distribution_description" {
  description = "CloudFront distribution description"
  type        = string
  default     = "Slackbot API"
}

variable "distribution_enabled" {
  description = "CloudFront distribution enabled switch"
  type        = bool
  default     = true
}

variable "distribution_http_version" {
  description = "CloudFront distribution HTTP version option"
  type        = string
  default     = "http2and3"
}

variable "distribution_is_ipv6_enabled" {
  description = "CloudFront distribution IPv6 switch"
  type        = bool
  default     = true
}

variable "distribution_logging_configurations" {
  description = "CloudFront distribution logging configurations"
  default     = []

  type = list(object({
    bucket          = string
    prefix          = optional(string)
    include_cookies = optional(bool)
  }))
}

variable "distribution_origin_domain_name" {
  description = "CloudFront distribution origin domain name"
  type        = string
}

variable "distribution_price_class" {
  type        = string
  description = "CloudFront distribution price class"
  default     = "PriceClass_All"
}

variable "distribution_restrictions_locations" {
  description = "CloudFront distribution restrictions locations"
  type        = list(string)
  default     = []
}

variable "distribution_restrictions_type" {
  description = "CloudFront distribution restrictions type"
  type        = string
  default     = "none"
}

variable "distribution_viewer_certificate" {
  description = "CloudFront distribution viewer certificate configuration"
  default     = { cloudfront_default_certificate = true }

  type = object({
    acm_certificate_arn            = optional(string)
    cloudfront_default_certificate = optional(bool)
    iam_certificate_id             = optional(string)
    minimum_protocol_version       = optional(string)
    ssl_support_method             = optional(string)
  })
}

##############
#   SECRET   #
##############

variable "secret_hash" {
  description = "SecretsManager secret hash (to trigger redeployment)"
  type        = string
  default     = ""
}

variable "secret_name" {
  description = "SecretsManager secret name"
  type        = string
}

###########
#   DNS   #
###########

variable "zone_id" {
  description = "Route53 zone ID"
  type        = string
}
