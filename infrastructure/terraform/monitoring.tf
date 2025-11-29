# API Error Rate Alarm
resource "aws_cloudwatch_metric_alarm" "api_errors" {
  alarm_name          = "nerdy-ai-high-error-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "RequestCount"
  namespace           = "NerdyAI/Production"
  period              = 300
  statistic           = "Sum"
  threshold           = 50
  alarm_description   = "API error rate is too high"

  dimensions = {
    StatusCode = "5XX"
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]
}

# AI API Cost Alarm
resource "aws_cloudwatch_metric_alarm" "ai_cost" {
  alarm_name          = "nerdy-ai-high-ai-cost"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "AI_Cost"
  namespace           = "NerdyAI/Production"
  period              = 3600
  statistic           = "Sum"
  threshold           = 100
  alarm_description   = "AI API cost exceeds $100/hour"

  alarm_actions = [aws_sns_topic.alerts.arn]
}

# Database Connections Alarm
resource "aws_cloudwatch_metric_alarm" "db_connections" {
  alarm_name          = "nerdy-ai-db-connections"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "Database connections exceeding threshold"

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.postgres.id
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
}

# ECS CPU Utilization Alarm
resource "aws_cloudwatch_metric_alarm" "ecs_cpu" {
  alarm_name          = "nerdy-ai-ecs-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "ECS CPU utilization is high"

  dimensions = {
    ClusterName = aws_ecs_cluster.main.name
    ServiceName = aws_ecs_service.api.name
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
}

# Response Time Alarm
resource "aws_cloudwatch_metric_alarm" "response_time" {
  alarm_name          = "nerdy-ai-slow-responses"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "RequestDuration"
  namespace           = "NerdyAI/Production"
  period              = 300
  statistic           = "p95"
  threshold           = 2000
  alarm_description   = "P95 response time exceeds 2 seconds"

  alarm_actions = [aws_sns_topic.alerts.arn]
}

# SNS Topic for Alerts
resource "aws_sns_topic" "alerts" {
  name = "nerdy-ai-alerts"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_sns_topic_subscription" "slack" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "https"
  endpoint  = var.slack_webhook_url
}

# CloudWatch Dashboard
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "NerdyAI-Production"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "API Request Rate"
          region = var.aws_region
          metrics = [
            ["NerdyAI/Production", "RequestCount", { stat = "Sum", period = 60 }]
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "Response Time (p95)"
          region = var.aws_region
          metrics = [
            ["NerdyAI/Production", "RequestDuration", { stat = "p95", period = 60 }]
          ]
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 8
        height = 6
        properties = {
          title  = "AI API Cost"
          region = var.aws_region
          metrics = [
            ["NerdyAI/Production", "AI_Cost", { stat = "Sum", period = 3600 }]
          ]
        }
      },
      {
        type   = "metric"
        x      = 8
        y      = 6
        width  = 8
        height = 6
        properties = {
          title  = "AI Cache Hit Rate"
          region = var.aws_region
          metrics = [
            ["NerdyAI/Production", "AI_CacheHit", { stat = "Average", period = 300 }]
          ]
        }
      },
      {
        type   = "metric"
        x      = 16
        y      = 6
        width  = 8
        height = 6
        properties = {
          title  = "Error Rate"
          region = var.aws_region
          metrics = [
            ["NerdyAI/Production", "AI_Error", { stat = "Sum", period = 300 }]
          ]
        }
      }
    ]
  })
}


