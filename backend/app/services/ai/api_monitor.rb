# frozen_string_literal: true

module AI
  class ApiMonitor
    include Singleton

    METRICS = %i[
      requests_total
      tokens_input
      tokens_output
      cost_total
      latency_avg
      errors_total
      cache_hits
      cache_misses
    ].freeze

    def initialize
      @redis = Redis.new(url: ENV['REDIS_URL'])
      @metrics_key = 'ai:metrics'
    end

    def record_request(model:, tokens_in:, tokens_out:, latency:, cached: false, error: nil)
      now = Time.current
      hour_key = now.strftime('%Y-%m-%d-%H')

      cost = calculate_cost(model, tokens_in, tokens_out)

      @redis.pipelined do |pipeline|
        pipeline.hincrby("#{@metrics_key}:#{hour_key}", 'requests_total', 1)
        pipeline.hincrby("#{@metrics_key}:#{hour_key}", 'tokens_input', tokens_in)
        pipeline.hincrby("#{@metrics_key}:#{hour_key}", 'tokens_output', tokens_out)
        pipeline.hincrbyfloat("#{@metrics_key}:#{hour_key}", 'cost_total', cost)

        if cached
          pipeline.hincrby("#{@metrics_key}:#{hour_key}", 'cache_hits', 1)
        else
          pipeline.hincrby("#{@metrics_key}:#{hour_key}", 'cache_misses', 1)
        end

        if error
          pipeline.hincrby("#{@metrics_key}:#{hour_key}", 'errors_total', 1)
        end

        # Store latency samples for percentile calculation
        pipeline.lpush("#{@metrics_key}:latency:#{hour_key}", latency)
        pipeline.ltrim("#{@metrics_key}:latency:#{hour_key}", 0, 999)

        # Set TTL for cleanup (7 days)
        pipeline.expire("#{@metrics_key}:#{hour_key}", 7.days.to_i)
        pipeline.expire("#{@metrics_key}:latency:#{hour_key}", 7.days.to_i)
      end

      # Publish to CloudWatch
      publish_to_cloudwatch(model, tokens_in, tokens_out, cost, latency, cached, error)
    end

    def get_hourly_stats(hours: 24)
      now = Time.current
      stats = []

      hours.times do |i|
        hour = now - i.hours
        hour_key = hour.strftime('%Y-%m-%d-%H')

        data = @redis.hgetall("#{@metrics_key}:#{hour_key}")
        latencies = @redis.lrange("#{@metrics_key}:latency:#{hour_key}", 0, -1).map(&:to_f)

        stats << {
          hour: hour.beginning_of_hour,
          requests: data['requests_total'].to_i,
          tokens_in: data['tokens_input'].to_i,
          tokens_out: data['tokens_output'].to_i,
          cost: data['cost_total'].to_f.round(4),
          cache_hit_rate: calculate_cache_rate(data),
          error_rate: calculate_error_rate(data),
          latency_p50: percentile(latencies, 50),
          latency_p95: percentile(latencies, 95),
          latency_p99: percentile(latencies, 99)
        }
      end

      stats.reverse
    end

    def get_daily_summary
      now = Time.current
      today_start = now.beginning_of_day

      totals = {
        requests: 0,
        tokens_in: 0,
        tokens_out: 0,
        cost: 0.0,
        errors: 0,
        cache_hits: 0,
        cache_misses: 0
      }

      24.times do |i|
        hour = today_start + i.hours
        next if hour > now

        hour_key = hour.strftime('%Y-%m-%d-%H')
        data = @redis.hgetall("#{@metrics_key}:#{hour_key}")

        totals[:requests] += data['requests_total'].to_i
        totals[:tokens_in] += data['tokens_input'].to_i
        totals[:tokens_out] += data['tokens_output'].to_i
        totals[:cost] += data['cost_total'].to_f
        totals[:errors] += data['errors_total'].to_i
        totals[:cache_hits] += data['cache_hits'].to_i
        totals[:cache_misses] += data['cache_misses'].to_i
      end

      totals[:cache_hit_rate] = totals[:cache_hits].to_f / (totals[:cache_hits] + totals[:cache_misses]) rescue 0
      totals[:error_rate] = totals[:errors].to_f / totals[:requests] rescue 0

      totals
    end

    private

    def calculate_cost(model, tokens_in, tokens_out)
      rates = {
        'gpt-4-turbo' => { input: 0.01, output: 0.03 },
        'gpt-4o' => { input: 0.005, output: 0.015 },
        'gpt-3.5-turbo' => { input: 0.0005, output: 0.0015 }
      }

      rate = rates[model] || rates['gpt-4-turbo']

      (tokens_in / 1000.0 * rate[:input]) + (tokens_out / 1000.0 * rate[:output])
    end

    def calculate_cache_rate(data)
      hits = data['cache_hits'].to_i
      misses = data['cache_misses'].to_i
      return 0 if hits + misses == 0

      (hits.to_f / (hits + misses) * 100).round(2)
    end

    def calculate_error_rate(data)
      requests = data['requests_total'].to_i
      errors = data['errors_total'].to_i
      return 0 if requests == 0

      (errors.to_f / requests * 100).round(2)
    end

    def percentile(array, percentile)
      return 0 if array.empty?

      sorted = array.sort
      index = (percentile / 100.0 * (sorted.length - 1)).round
      sorted[index].round(2)
    end

    def publish_to_cloudwatch(model, tokens_in, tokens_out, cost, latency, cached, error)
      dimensions = [{ name: 'Model', value: model }]

      CloudWatch::MetricsPublisher.publish('AI_TokensInput', tokens_in, dimensions: dimensions)
      CloudWatch::MetricsPublisher.publish('AI_TokensOutput', tokens_out, dimensions: dimensions)
      CloudWatch::MetricsPublisher.publish('AI_Cost', cost, unit: 'None', dimensions: dimensions)
      CloudWatch::MetricsPublisher.publish('AI_Latency', latency, unit: 'Milliseconds', dimensions: dimensions)
      CloudWatch::MetricsPublisher.publish('AI_CacheHit', cached ? 1 : 0, dimensions: dimensions)
      CloudWatch::MetricsPublisher.publish('AI_Error', error ? 1 : 0, dimensions: dimensions) if error
    end
  end
end


