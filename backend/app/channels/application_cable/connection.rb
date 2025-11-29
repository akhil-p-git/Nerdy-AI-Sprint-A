module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_student

    def connect
      self.current_student = find_verified_student
    end

    private

    def find_verified_student
      token = request.params[:token]
      payload = JwtService.decode(token)

      if payload && (student = Student.find_by(id: payload[:student_id]))
        student
      else
        reject_unauthorized_connection
      end
    end
  end
end

