class SyncStudentSessionsJob < ApplicationJob
  queue_as :default

  def perform(student_id)
    student = Student.find(student_id)
    service = Nerdy::SessionSyncService.new(student: student)
    service.sync_recent_sessions
  end
end


