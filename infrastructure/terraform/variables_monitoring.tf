variable "alert_email" {
  description = "Email for alerts"
  type        = string
}

variable "slack_webhook_url" {
  description = "Slack webhook for alerts"
  type        = string
  sensitive   = true
}


