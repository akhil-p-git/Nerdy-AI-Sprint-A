module Authenticatable
  extend ActiveSupport::Concern

  included do
    before_action :authenticate_request
  end

  private

  def authenticate_request
    token = extract_token
    payload = JwtService.decode(token)

    if payload && payload[:student_id]
      @current_student = Student.find_by(id: payload[:student_id])
      render json: { error: 'User not found' }, status: :unauthorized unless @current_student
    else
      render json: { error: 'Invalid or expired token' }, status: :unauthorized
    end
  end

  def extract_token
    header = request.headers['Authorization']
    header&.split(' ')&.last
  end

  def current_student
    @current_student
  end
end

