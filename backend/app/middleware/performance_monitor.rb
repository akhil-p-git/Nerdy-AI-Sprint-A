# frozen_string_literal: true

class PerformanceMonitor
  def initialize(app)
    @app = app
  end

  def call(env)
    start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    status, headers, response = @app.call(env)

    duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time

    record_metrics(env, status, duration)

    [status, headers, response]
  end

  private

  def record_metrics(env, status, duration)
    path = env['PATH_INFO']
    method = env['REQUEST_METHOD']

    # Skip health checks
    return if path == '/health'

    CloudWatch::MetricsPublisher.publish(
      'RequestDuration',
      (duration * 1000).round(2),
      unit: 'Milliseconds',
      dimensions: [
        { name: 'Path', value: normalize_path(path) },
        { name: 'Method', value: method }
      ]
    )

    CloudWatch::MetricsPublisher.publish(
      'RequestCount',
      1,
      dimensions: [
        { name: 'StatusCode', value: status.to_s },
        { name: 'Path', value: normalize_path(path) }
      ]
    )

    # Alert on slow requests
    if duration > 2.0
      Sentry.capture_message(
        "Slow request: #{method} #{path}",
        level: :warning,
        extra: { duration: duration, status: status }
      )
    end
  end

  def normalize_path(path)
    # Replace IDs with placeholder
    path.gsub(/\/\d+/, '/:id')
  end
end


