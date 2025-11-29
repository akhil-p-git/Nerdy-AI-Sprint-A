module Retention
  class EngagementTracker
    # Thresholds for nudges
    MIN_SESSIONS_BY_DAY_7 = 3
    INACTIVE_DAYS_THRESHOLD = 7
    LOW_PRACTICE_THRESHOLD = 2 # practices per week

    def initialize(student:)
      @student = student
    end

    # Calculate overall engagement score (0-100)
    def engagement_score
      scores = {
        session_frequency: session_frequency_score,
        practice_activity: practice_activity_score,
        conversation_activity: conversation_activity_score,
        goal_progress: goal_progress_score,
        recency: recency_score
      }

      weights = {
        session_frequency: 0.3,
        practice_activity: 0.25,
        conversation_activity: 0.2,
        goal_progress: 0.15,
        recency: 0.1
      }

      weighted_score = scores.sum { |k, v| v * weights[k] }
      weighted_score.round
    end

    # Check if student needs a nudge
    def needs_nudge?
      return true if new_student_low_sessions?
      return true if inactive_too_long?
      return true if declining_engagement?
      return true if stalled_goal_progress?
      false
    end

    # Get appropriate nudge type
    def recommended_nudge
      return :new_student_sessions if new_student_low_sessions?
      return :inactive_reminder if inactive_too_long?
      return :declining_engagement if declining_engagement?
      return :goal_stalled if stalled_goal_progress?
      return :general_encouragement if engagement_score < 50
      nil
    end

    # Get nudge content
    def nudge_content
      case recommended_nudge
      when :new_student_sessions
        new_student_nudge_content
      when :inactive_reminder
        inactive_nudge_content
      when :declining_engagement
        declining_engagement_content
      when :goal_stalled
        goal_stalled_content
      when :general_encouragement
        encouragement_content
      end
    end

    private

    def session_frequency_score
      days_active = (@student.created_at.to_date..Date.current).count
      return 100 if days_active < 7

      sessions_count = @student.tutoring_sessions
        .where('created_at > ?', 30.days.ago)
        .count

      expected_sessions = (days_active / 7.0).ceil * 2 # ~2 sessions per week
      [sessions_count.to_f / expected_sessions * 100, 100].min.round
    end

    def practice_activity_score
      practices = @student.practice_sessions
        .where('created_at > ?', 14.days.ago)
        .count

      [practices.to_f / 7 * 100, 100].min.round # Expect ~7 in 2 weeks
    end

    def conversation_activity_score
      conversations = @student.conversations
        .where('updated_at > ?', 7.days.ago)
        .count

      messages = Message.joins(:conversation)
        .where(conversations: { student_id: @student.id })
        .where('messages.created_at > ?', 7.days.ago)
        .count

      activity = conversations * 10 + messages
      [activity.to_f / 20 * 100, 100].min.round
    end

    def goal_progress_score
      active_goals = @student.learning_goals.where(status: :active)
      return 50 if active_goals.empty? # Neutral if no goals

      avg_progress = active_goals.average(:progress_percentage) || 0
      avg_progress.round
    end

    def recency_score
      last_activity = [
        @student.tutoring_sessions.maximum(:created_at),
        @student.practice_sessions.maximum(:created_at),
        @student.conversations.maximum(:updated_at)
      ].compact.max

      return 0 unless last_activity

      days_since = (Date.current - last_activity.to_date).to_i
      [100 - (days_since * 10), 0].max
    end

    def new_student_low_sessions?
      days_since_signup = (Date.current - @student.created_at.to_date).to_i
      return false if days_since_signup > 14 # Not a new student

      if days_since_signup >= 7
        session_count = @student.tutoring_sessions
          .where('created_at > ?', @student.created_at)
          .count
        session_count < MIN_SESSIONS_BY_DAY_7
      else
        false
      end
    end

    def inactive_too_long?
      last_activity = [
        @student.tutoring_sessions.maximum(:created_at),
        @student.practice_sessions.maximum(:created_at),
        @student.conversations.maximum(:updated_at)
      ].compact.max

      return true unless last_activity
      (Date.current - last_activity.to_date).to_i >= INACTIVE_DAYS_THRESHOLD
    end

    def declining_engagement?
      # Compare last 2 weeks to previous 2 weeks
      recent = engagement_in_period(14.days.ago, Date.current)
      previous = engagement_in_period(28.days.ago, 14.days.ago)

      return false if previous == 0
      recent < previous * 0.5 # Dropped by more than 50%
    end

    def engagement_in_period(start_date, end_date)
      sessions = @student.tutoring_sessions.where(created_at: start_date..end_date).count
      practices = @student.practice_sessions.where(created_at: start_date..end_date).count
      conversations = @student.conversations.where(updated_at: start_date..end_date).count

      sessions * 3 + practices * 2 + conversations
    end

    def stalled_goal_progress?
      stalled_goals = @student.learning_goals
        .where(status: :active)
        .where('updated_at < ?', 14.days.ago)
        .where('progress_percentage < 80')

      stalled_goals.exists?
    end

    def new_student_nudge_content
      {
        type: 'new_student_sessions',
        title: "Let's keep the momentum going! 🚀",
        message: "Students who have 3+ sessions in their first week see 2x better results. Book your next session to stay on track!",
        cta: 'Book a Session',
        cta_action: 'book_session',
        priority: 'high'
      }
    end

    def inactive_nudge_content
      days = (Date.current - last_activity_date).to_i
      {
        type: 'inactive_reminder',
        title: "We miss you! 👋",
        message: "It's been #{days} days since your last activity. Your AI companion is ready to help you practice anytime!",
        cta: 'Start Practicing',
        cta_action: 'open_practice',
        priority: 'medium'
      }
    end

    def declining_engagement_content
      {
        type: 'declining_engagement',
        title: "Need a hand? 🤝",
        message: "We noticed you've been less active lately. Is there something we can help with? A quick practice session can help you get back on track.",
        cta: 'Quick Practice',
        cta_action: 'open_practice',
        priority: 'medium'
      }
    end

    def goal_stalled_content
      stalled_goal = @student.learning_goals
        .where(status: :active)
        .where('updated_at < ?', 14.days.ago)
        .first

      {
        type: 'goal_stalled',
        title: "Let's get you unstuck! 💪",
        message: "Your goal '#{stalled_goal&.title}' hasn't seen progress in a while. A tutor session could help break through!",
        cta: 'Book Tutor Session',
        cta_action: 'book_session',
        cta_data: { subject: stalled_goal&.subject },
        priority: 'high'
      }
    end

    def encouragement_content
      {
        type: 'encouragement',
        title: "You're doing great! 🌟",
        message: "Every bit of practice counts. Your AI companion has some new questions ready for you!",
        cta: 'Start Learning',
        cta_action: 'open_companion',
        priority: 'low'
      }
    end

    def last_activity_date
      [
        @student.tutoring_sessions.maximum(:created_at),
        @student.practice_sessions.maximum(:created_at),
        @student.conversations.maximum(:updated_at)
      ].compact.max&.to_date || @student.created_at.to_date
    end
  end
end


