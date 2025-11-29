class CheckEngagementJob < ApplicationJob
  queue_as :low

  def perform
    # Run daily to check all students
    Student.find_each do |student|
      tracker = Retention::EngagementTracker.new(student: student)

      if tracker.needs_nudge?
        nudge = tracker.nudge_content
        next unless nudge

        # Check if we've already sent this type recently
        recent_nudge = StudentNudge.where(student: student, nudge_type: nudge[:type])
          .where('created_at > ?', 3.days.ago)
          .exists?

        unless recent_nudge
          SendRetentionNudgeJob.perform_later(student.id, nudge[:type], nudge)
        end
      end
    end
  end
end


