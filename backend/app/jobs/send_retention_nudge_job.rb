class SendRetentionNudgeJob < ApplicationJob
  queue_as :default

  def perform(student_id, nudge_type, nudge_data = {})
    student = Student.find(student_id)
    client = Nerdy::PlatformClient.new

    # Get nudge content
    content = nudge_data.presence || generate_nudge_content(student, nudge_type)
    return unless content

    # Record the nudge
    StudentNudge.create!(
      student: student,
      nudge_type: nudge_type,
      content: content,
      sent_at: Time.current
    )

    # Send via Nerdy platform
    client.send_notification(
      student_id: student.external_id,
      type: nudge_type,
      title: content[:title],
      message: content[:message],
      data: {
        cta: content[:cta],
        cta_action: content[:cta_action],
        cta_data: content[:cta_data]
      }
    )

    # Also create in-app notification
    StudentEvent.create!(
      student: student,
      event_type: 'nudge',
      data: content,
      expires_at: 7.days.from_now
    )
  end

  private

  def generate_nudge_content(student, nudge_type)
    tracker = Retention::EngagementTracker.new(student: student)
    tracker.nudge_content
  end
end


