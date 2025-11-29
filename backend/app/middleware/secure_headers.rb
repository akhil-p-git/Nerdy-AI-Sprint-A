class SecureHeaders
  def initialize(app)
    @app = app
  end

  def call(env)
    status, headers, response = @app.call(env)

    # Security headers
    headers['X-Content-Type-Options'] = 'nosniff'
    headers['X-Frame-Options'] = 'DENY'
    headers['X-XSS-Protection'] = '1; mode=block'
    headers['Referrer-Policy'] = 'strict-origin-when-cross-origin'
    headers['Permissions-Policy'] = 'geolocation=(), microphone=(), camera=()'

    # Content Security Policy
    headers['Content-Security-Policy'] = csp_header

    # Strict Transport Security (for production)
    if Rails.env.production?
      headers['Strict-Transport-Security'] = 'max-age=31536000; includeSubDomains'
    end

    [status, headers, response]
  end

  private

  def csp_header
    [
      "default-src 'self'",
      "script-src 'self' 'unsafe-inline' 'unsafe-eval'",
      "style-src 'self' 'unsafe-inline'",
      "img-src 'self' data: https:",
      "font-src 'self' data:",
      "connect-src 'self' #{allowed_api_origins}",
      "frame-ancestors 'none'"
    ].join('; ')
  end

  def allowed_api_origins
    [
      ENV['FRONTEND_URL'],
      'wss://*.nerdy.com',
      'https://api.openai.com'
    ].compact.join(' ')
  end
end


