class RateLimiter
  LIMITS = {
    default: { requests: 100, period: 60 },           # 100 req/min
    ai_conversation: { requests: 20, period: 60 },    # 20 req/min
    ai_practice: { requests: 10, period: 60 },        # 10 req/min
    auth: { requests: 5, period: 60 }                 # 5 req/min
  }.freeze

  def initialize(app)
    @app = app
  end

  def call(env)
    request = Rack::Request.new(env)

    # Skip rate limiting for non-API routes
    return @app.call(env) unless request.path.start_with?('/api/')

    # Determine limit type based on path
    limit_type = determine_limit_type(request.path)
    limits = LIMITS[limit_type]

    # Get identifier (user ID from JWT or IP)
    identifier = extract_identifier(request)

    # Check rate limit
    key = "rate_limit:#{limit_type}:#{identifier}"

    current_count = REDIS.get(key).to_i

    if current_count >= limits[:requests]
      return rate_limit_exceeded_response(limits)
    end

    # Increment counter
    REDIS.multi do |multi|
      multi.incr(key)
      multi.expire(key, limits[:period]) if current_count.zero?
    end

    # Add rate limit headers
    status, headers, response = @app.call(env)

    headers['X-RateLimit-Limit'] = limits[:requests].to_s
    headers['X-RateLimit-Remaining'] = (limits[:requests] - current_count - 1).to_s
    headers['X-RateLimit-Reset'] = (Time.now.to_i + REDIS.ttl(key)).to_s

    [status, headers, response]
  end

  private

  def determine_limit_type(path)
    case path
    when %r{/api/v1/conversations/.*/messages}
      :ai_conversation
    when %r{/api/v1/practice_sessions}
      :ai_practice
    when %r{/api/v1/auth}
      :auth
    else
      :default
    end
  end

  def extract_identifier(request)
    token = request.get_header('HTTP_AUTHORIZATION')&.split(' ')&.last
    if token
      payload = JwtService.decode(token)
      return "user:#{payload[:student_id]}" if payload
    end
    "ip:#{request.ip}"
  end

  def rate_limit_exceeded_response(limits)
    [
      429,
      {
        'Content-Type' => 'application/json',
        'Retry-After' => limits[:period].to_s
      },
      [{ error: 'Rate limit exceeded', retry_after: limits[:period] }.to_json]
    ]
  end
end


