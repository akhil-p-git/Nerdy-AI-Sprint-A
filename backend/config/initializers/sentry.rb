# frozen_string_literal: true

return unless defined?(Sentry) && ENV['SENTRY_DSN'].present?

Sentry.init do |config|
  config.dsn = ENV['SENTRY_DSN']
  config.breadcrumbs_logger = [:active_support_logger, :http_logger]
  config.traces_sample_rate = 0.1
  config.profiles_sample_rate = 0.1

  config.environment = Rails.env
  config.enabled_environments = %w[production staging]

  config.excluded_exceptions += [
    'ActionController::RoutingError',
    'ActiveRecord::RecordNotFound',
    'ActionController::InvalidAuthenticityToken'
  ]

  config.before_send = lambda do |event, hint|
    # Filter sensitive data
    if event.request&.data
      event.request.data = filter_sensitive_params(event.request.data)
    end

    # Add custom context
    event.tags[:ai_model] = 'gpt-4-turbo'

    event
  end
end

def filter_sensitive_params(data)
  return data unless data.is_a?(Hash)

  sensitive_keys = %w[password password_confirmation api_key token secret]
  data.transform_values do |value|
    if sensitive_keys.include?(key.to_s.downcase)
      '[FILTERED]'
    elsif value.is_a?(Hash)
      filter_sensitive_params(value)
    else
      value
    end
  end
end


