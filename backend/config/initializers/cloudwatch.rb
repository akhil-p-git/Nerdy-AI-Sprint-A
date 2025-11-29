# frozen_string_literal: true

return unless Rails.env.production?

require 'aws-sdk-cloudwatchlogs'

if Rails.env.production?
  Rails.application.configure do
    config.logger = ActiveSupport::TaggedLogging.new(
      ActiveSupport::Logger.new($stdout)
    )
    config.log_level = :info
    config.log_tags = [:request_id]
  end
end

module CloudWatch
  class MetricsPublisher
    include Singleton

    def initialize
      @client = Aws::CloudWatch::Client.new(region: ENV.fetch('AWS_REGION', 'us-east-1'))
      @namespace = 'NerdyAI/Production'
      @buffer = []
      @mutex = Mutex.new
    end

    def publish(metric_name, value, unit: 'Count', dimensions: [])
      @mutex.synchronize do
        @buffer << {
          metric_name: metric_name,
          value: value,
          unit: unit,
          dimensions: dimensions,
          timestamp: Time.current
        }

        flush if @buffer.size >= 20
      end
    end

    def flush
      return if @buffer.empty?

      metrics = @buffer.dup
      @buffer.clear

      Thread.new do
        @client.put_metric_data(
          namespace: @namespace,
          metric_data: metrics
        )
      rescue Aws::CloudWatch::Errors::ServiceError => e
        Rails.logger.error("CloudWatch publish error: #{e.message}")
      end
    end

    def self.publish(...)
      instance.publish(...)
    end
  end
end


