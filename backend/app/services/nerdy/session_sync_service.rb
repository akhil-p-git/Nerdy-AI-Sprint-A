module Nerdy
  class SessionSyncService
    def initialize(student:)
      @student = student
      @client = PlatformClient.new
      @memory_service = AI::MemoryService.new(student: student)
    end

    # Sync all recent sessions for a student
    def sync_recent_sessions(since: 30.days.ago)
      external_sessions = @client.get_student_sessions(@student.external_id, since: since)

      external_sessions.map do |session_data|
        sync_session(session_data)
      end.compact
    end

    # Sync a single session
    def sync_session(session_data)
      # Find or create local session record
      session = TutoringSession.find_or_initialize_by(
        external_session_id: session_data['id']
      )

      # Skip if already fully processed
      return session if session.persisted? && session.summary.present?

      # Find or create tutor
      tutor = sync_tutor(session_data['tutor']) if session_data['tutor']

      # Update session details
      session.assign_attributes(
        student: @student,
        tutor: tutor,
        subject: session_data['subject'],
        started_at: session_data['started_at'],
        ended_at: session_data['ended_at'],
        transcript_url: session_data['transcript_url']
      )

      session.save!

      # Process transcript asynchronously
      ProcessSessionJob.perform_later(session.id) if session.transcript_url.present?

      session
    end

    private

    def sync_tutor(tutor_data)
      Tutor.find_or_create_by(external_id: tutor_data['id']) do |t|
        t.email = tutor_data['email']
        t.first_name = tutor_data['first_name']
        t.last_name = tutor_data['last_name']
        t.subjects = tutor_data['subjects'] || []
      end
    end
  end
end


