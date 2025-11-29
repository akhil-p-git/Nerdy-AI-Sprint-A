class GoalCompletionJob < ApplicationJob
  queue_as :default

  def perform(goal_id)
    goal = LearningGoal.find(goal_id)
    student = goal.student

    # Get recommendations
    recommendations = Retention::SubjectRecommendations.get_recommendations(goal.subject)

    # Send celebration notification
    send_completion_notification(student, goal, recommendations)

    # Create in-app celebration event
    create_celebration_event(student, goal)

    # Schedule follow-up nudge if no new goal created
    schedule_followup_nudge(student, goal)

    # Update analytics
    track_goal_completion(student, goal)
  end

  private

  def send_completion_notification(student, goal, recommendations)
    client = Nerdy::PlatformClient.new

    client.send_notification(
      student_id: student.external_id,
      type: 'goal_completed',
      title: "🎉 Goal Achieved: #{goal.title}!",
      message: recommendations[:message],
      data: {
        goal_id: goal.id,
        subject: goal.subject,
        next_subjects: recommendations[:next_subjects],
        cta_type: 'explore_subjects'
      }
    )
  end

  def create_celebration_event(student, goal)
    # Store event for frontend to display celebration UI
    StudentEvent.create!(
      student: student,
      event_type: 'goal_completed',
      data: {
        goal_id: goal.id,
        goal_title: goal.title,
        subject: goal.subject,
        suggested_next: goal.suggested_next_goals
      },
      expires_at: 7.days.from_now
    )
  end

  def schedule_followup_nudge(student, goal)
    # If student doesn't create a new goal within 3 days, send a nudge
    SendRetentionNudgeJob.set(wait: 3.days).perform_later(
      student.id,
      'goal_completed_followup',
      { completed_goal_id: goal.id }
    )
  end

  def track_goal_completion(student, goal)
    # Analytics tracking - integrate with your analytics service
    Rails.logger.info({
      event: 'goal_completed',
      student_id: student.id,
      goal_id: goal.id,
      subject: goal.subject,
      days_to_complete: (goal.completed_at.to_date - goal.created_at.to_date).to_i
    }.to_json)
  end
end


