class JwtService
  SECRET_KEY = Rails.application.credentials.jwt_secret_key || ENV['JWT_SECRET_KEY']
  ALGORITHM = 'HS256'

  def self.encode(payload, exp = 24.hours.from_now)
    payload[:exp] = exp.to_i
    JWT.encode(payload, SECRET_KEY, ALGORITHM)
  end

  def self.decode(token)
    decoded = JWT.decode(token, SECRET_KEY, true, algorithm: ALGORITHM)
    HashWithIndifferentAccess.new(decoded.first)
  rescue JWT::DecodeError, JWT::ExpiredSignature => e
    Rails.logger.error("JWT Error: #{e.message}")
    nil
  end
end

