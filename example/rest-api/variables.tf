
###########
#   API   #
###########

variable "api_description" {
  type        = string
  description = "Slack API description"
  default     = "Slack API"
}

variable "api_name" {
  type        = string
  description = "Slack API name"
}

variable "api_integration_description" {
  type        = string
  description = "Slack API default integration description"
  default     = "Slack API default integration"
}

variable "api_stage_description" {
  type        = string
  description = "Slack API default stage description"
  default     = "Slack API default stage"
}

variable "api_certificate_arn" {
  description = "Slack API certificate ARN"
  type        = string
}

variable "api_domain" {
  description = "Slack API domain"
  type        = string
}

variable "api_zone_id" {
  description = "Slack API Route53 zone ID"
  type        = string
}

######################
#   DEFAULT LAMBDA   #
######################

variable "default_function_description" {
  type        = string
  description = "Default Slack handler function description"
  default     = "Default Slack handler"
}

variable "default_function_logs_retention_in_days" {
  type        = number
  description = "Default Slack handler function log retention in days"
  default     = 14
}

variable "default_function_name" {
  type        = string
  description = "Default Slack handler function name"
}

############
#   LOGS   #
############

variable "log_retention_in_days" {
  type        = number
  description = "Slack API log retention in days"
  default     = 14
}
