module Nerdy
  class PlatformClient
    BASE_URL = ENV.fetch('NERDY_PLATFORM_URL', 'https://api.nerdy.com')

    def initialize
      @connection = Faraday.new(url: BASE_URL) do |f|
        f.request :json
        f.response :json
        f.adapter Faraday.default_adapter
        f.headers['Authorization'] = "Bearer #{ENV['NERDY_API_KEY']}"
        f.headers['Content-Type'] = 'application/json'
      end
    end

    # Fetch session recordings for a student
    def get_student_sessions(external_student_id, since: 30.days.ago)
      response = @connection.get('/api/v1/sessions', {
        student_id: external_student_id,
        since: since.iso8601,
        include: 'transcript,recording'
      })

      return [] unless response.success?
      response.body['sessions'] || []
    end

    # Get single session details
    def get_session(external_session_id)
      response = @connection.get("/api/v1/sessions/#{external_session_id}")
      return nil unless response.success?
      response.body
    end

    # Get session transcript
    def get_transcript(external_session_id)
      response = @connection.get("/api/v1/sessions/#{external_session_id}/transcript")
      return nil unless response.success?
      response.body['transcript']
    end

    # Get available tutors for booking
    def get_available_tutors(subject:, datetime:, duration: 60)
      response = @connection.get('/api/v1/tutors/availability', {
        subject: subject,
        datetime: datetime.iso8601,
        duration: duration
      })

      return [] unless response.success?
      response.body['tutors'] || []
    end

    # Create a booking
    def create_booking(student_id:, tutor_id:, subject:, datetime:, notes: nil)
      response = @connection.post('/api/v1/bookings', {
        student_id: student_id,
        tutor_id: tutor_id,
        subject: subject,
        scheduled_at: datetime.iso8601,
        notes: notes
      })

      response.success? ? response.body : nil
    end

    # Send notification to student
    def send_notification(student_id:, type:, title:, message:, data: {})
      response = @connection.post('/api/v1/notifications', {
        student_id: student_id,
        notification_type: type,
        title: title,
        message: message,
        data: data
      })

      response.success?
    end
  end
end


