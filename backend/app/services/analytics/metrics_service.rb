module Analytics
  class MetricsService
    class << self
      # Track an event
      def track(event_name, properties = {})
        AnalyticsEvent.create!(
          event_name: event_name,
          student_id: properties.delete(:student_id),
          properties: properties,
          occurred_at: Time.current
        )

        # Also send to external analytics if configured
        send_to_external(event_name, properties) if external_analytics_enabled?
      end

      # Conversation metrics
      def conversation_started(conversation)
        track('conversation_started', {
          student_id: conversation.student_id,
          conversation_id: conversation.id,
          subject: conversation.subject
        })
      end

      def message_sent(message)
        track('message_sent', {
          student_id: message.conversation.student_id,
          conversation_id: message.conversation_id,
          role: message.role,
          message_length: message.content.length
        })
      end

      # Practice metrics
      def practice_started(session)
        track('practice_started', {
          student_id: session.student_id,
          session_id: session.id,
          subject: session.subject,
          session_type: session.session_type,
          problem_count: session.total_problems
        })
      end

      def practice_completed(session)
        track('practice_completed', {
          student_id: session.student_id,
          session_id: session.id,
          subject: session.subject,
          accuracy: session.total_problems > 0 ? (session.correct_answers.to_f / session.total_problems * 100).round : 0,
          time_spent: session.time_spent_seconds,
          struggled_topics: session.struggled_topics
        })
      end

      # Goal metrics
      def goal_created(goal)
        track('goal_created', {
          student_id: goal.student_id,
          goal_id: goal.id,
          subject: goal.subject
        })
      end

      def goal_completed(goal)
        days_to_complete = goal.completed_at ? (goal.completed_at.to_date - goal.created_at.to_date).to_i : nil

        track('goal_completed', {
          student_id: goal.student_id,
          goal_id: goal.id,
          subject: goal.subject,
          days_to_complete: days_to_complete
        })
      end

      def goal_progress_updated(goal, old_progress, new_progress)
        track('goal_progress', {
          student_id: goal.student_id,
          goal_id: goal.id,
          old_progress: old_progress,
          new_progress: new_progress,
          delta: new_progress - old_progress
        })
      end

      # Engagement metrics
      def session_booked(student, subject)
        track('session_booked', {
          student_id: student.id,
          subject: subject
        })
      end

      def tutor_handoff(conversation, reasons)
        track('tutor_handoff', {
          student_id: conversation.student_id,
          conversation_id: conversation.id,
          subject: conversation.subject,
          reasons: reasons
        })
      end

      def nudge_sent(student, nudge_type)
        track('nudge_sent', {
          student_id: student.id,
          nudge_type: nudge_type
        })
      end

      def nudge_acted(student, nudge_type, action)
        track('nudge_acted', {
          student_id: student.id,
          nudge_type: nudge_type,
          action: action
        })
      end

      # Aggregation queries
      def daily_active_users(date: Date.current)
        AnalyticsEvent.where('DATE(occurred_at) = ?', date)
          .distinct
          .count(:student_id)
      end

      def weekly_retention(cohort_start:)
        cohort_students = Student.where('DATE(created_at) = ?', cohort_start).pluck(:id)
        return 0 if cohort_students.empty?

        retained = AnalyticsEvent
          .where(student_id: cohort_students)
          .where('occurred_at > ?', cohort_start + 7.days)
          .distinct
          .count(:student_id)

        (retained.to_f / cohort_students.length * 100).round(1)
      end

      def conversion_funnel(period: 30.days)
        start_date = period.ago

        {
          signups: Student.where('created_at > ?', start_date).count,
          first_conversation: AnalyticsEvent.where(event_name: 'conversation_started')
            .where('occurred_at > ?', start_date)
            .distinct.count(:student_id),
          first_practice: AnalyticsEvent.where(event_name: 'practice_started')
            .where('occurred_at > ?', start_date)
            .distinct.count(:student_id),
          goal_created: AnalyticsEvent.where(event_name: 'goal_created')
            .where('occurred_at > ?', start_date)
            .distinct.count(:student_id),
          session_booked: AnalyticsEvent.where(event_name: 'session_booked')
            .where('occurred_at > ?', start_date)
            .distinct.count(:student_id)
        }
      end

      def learning_outcomes(student_id, subject: nil)
        profiles = LearningProfile.where(student_id: student_id)
        profiles = profiles.where(subject: subject) if subject

        profiles.map do |profile|
          practice_sessions = PracticeSession.where(student_id: student_id, subject: profile.subject)

          {
            subject: profile.subject,
            proficiency_change: calculate_proficiency_trend(practice_sessions),
            accuracy_trend: calculate_accuracy_trend(practice_sessions),
            time_invested: practice_sessions.sum(:time_spent_seconds) / 60,
            problems_solved: practice_sessions.sum(:total_problems)
          }
        end
      end

      private

      def external_analytics_enabled?
        ENV['ANALYTICS_API_KEY'].present?
      end

      def send_to_external(event_name, properties)
        # Integration with Mixpanel, Amplitude, Segment, etc.
        # HTTParty.post(...)
      end

      def calculate_proficiency_trend(sessions)
        return 0 if sessions.count < 2

        recent = sessions.order(created_at: :desc).limit(5)
        older = sessions.order(created_at: :desc).offset(5).limit(5)

        return 0 if older.empty?

        recent_avg = avg_accuracy(recent)
        older_avg = avg_accuracy(older)

        ((recent_avg - older_avg) * 100).round(1)
      end

      def calculate_accuracy_trend(sessions)
        sessions.order(:created_at).map do |s|
          {
            date: s.created_at.to_date,
            accuracy: s.total_problems > 0 ? (s.correct_answers.to_f / s.total_problems * 100).round : 0
          }
        end
      end

      def avg_accuracy(sessions)
        total_correct = sessions.sum(:correct_answers)
        total_problems = sessions.sum(:total_problems)
        return 0 if total_problems.zero?
        total_correct.to_f / total_problems
      end
    end
  end
end


