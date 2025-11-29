module Api
  module V1
    class AuthController < ApplicationController
      skip_before_action :authenticate_request, only: [:login, :refresh]

      # POST /api/v1/auth/login
      # Validates token from Nerdy platform and creates local session
      def login
        # Accept Nerdy platform token and validate
        nerdy_token = params[:nerdy_token]

        # Validate with Nerdy platform (mock for now)
        user_data = validate_nerdy_token(nerdy_token)

        if user_data
          student = Student.find_or_create_by(external_id: user_data[:id]) do |s|
            s.email = user_data[:email]
            s.first_name = user_data[:first_name]
            s.last_name = user_data[:last_name]
          end

          token = JwtService.encode(student_id: student.id)
          refresh_token = JwtService.encode({ student_id: student.id }, 7.days.from_now)

          render json: {
            token: token,
            refresh_token: refresh_token,
            student: StudentSerializer.new(student)
          }
        else
          render json: { error: 'Invalid credentials' }, status: :unauthorized
        end
      end

      # POST /api/v1/auth/refresh
      def refresh
        refresh_token = params[:refresh_token]
        payload = JwtService.decode(refresh_token)

        if payload && payload[:student_id]
          student = Student.find(payload[:student_id])
          token = JwtService.encode(student_id: student.id)
          render json: { token: token }
        else
          render json: { error: 'Invalid refresh token' }, status: :unauthorized
        end
      end

      # GET /api/v1/auth/me
      def me
        render json: { student: StudentSerializer.new(current_student) }
      end

      private

      def validate_nerdy_token(token)
        # TODO: Integrate with actual Nerdy platform API
        # For now, mock validation
        return nil if token.blank?

        # Mock user data - replace with actual API call
        {
          id: "nerdy_#{SecureRandom.hex(8)}",
          email: "student@example.com",
          first_name: "Test",
          last_name: "Student"
        }
      end
    end
  end
end

