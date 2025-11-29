class ApplicationController < ActionController::API
  include Authenticatable
  include ParameterValidation

  # For API-only apps, we use JWT instead of CSRF tokens
  # But we still protect against CSRF for browser-based requests

  before_action :verify_request_origin

  rescue_from ActiveRecord::RecordNotFound, with: :not_found
  rescue_from ActiveRecord::RecordInvalid, with: :unprocessable_entity
  rescue_from ActionController::ParameterMissing, with: :bad_request

  private

  def verify_request_origin
    return unless request.headers['Origin'].present?

    allowed_origins = [
      ENV['FRONTEND_URL'],
      'http://localhost:5173',
      'http://localhost:3001'
    ].compact

    unless allowed_origins.include?(request.headers['Origin'])
      render json: { error: 'Invalid origin' }, status: :forbidden
    end
  end

  def not_found(exception)
    render json: { error: 'Resource not found' }, status: :not_found
  end

  def unprocessable_entity(exception)
    render json: { error: exception.record.errors.full_messages }, status: :unprocessable_entity
  end

  def bad_request(exception)
    render json: { error: exception.message }, status: :bad_request
  end
end
