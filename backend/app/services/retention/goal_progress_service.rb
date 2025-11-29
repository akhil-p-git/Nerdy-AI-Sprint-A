module Retention
  class GoalProgressService
    COMPLETION_THRESHOLD = 90 # percent

    def initialize(goal:)
      @goal = goal
      @student = goal.student
    end

    # Check progress after a session or practice
    def check_and_update(session: nil, analysis: nil, practice_session: nil)
      # Calculate progress from multiple signals
      progress = calculate_progress(session, analysis, practice_session)

      # Update goal
      @goal.update!(progress_percentage: progress)

      # Check for completion
      if progress >= COMPLETION_THRESHOLD && @goal.status != 'completed'
        complete_goal!
      end

      progress
    end

    # Manually trigger completion check
    def evaluate_completion
      signals = gather_completion_signals

      # Use AI to evaluate if goal is met
      evaluation = ai_evaluate_completion(signals)

      if evaluation[:is_complete]
        @goal.update!(progress_percentage: 100)
        complete_goal!
      else
        @goal.update!(progress_percentage: evaluation[:estimated_progress])
      end

      evaluation
    end

    private

    def calculate_progress(session, analysis, practice_session)
      scores = []

      # Session-based progress
      if session && analysis
        scores << analysis[:comprehension_score].to_i * 10 if analysis[:comprehension_score]
      end

      # Practice-based progress
      if practice_session
        accuracy = practice_session.correct_answers.to_f / practice_session.total_problems
        scores << (accuracy * 100).round
      end

      # Historical practice performance
      recent_practices = @student.practice_sessions
        .where(subject: @goal.subject)
        .where('created_at > ?', 30.days.ago)

      if recent_practices.any?
        avg_accuracy = recent_practices.average('correct_answers::float / NULLIF(total_problems, 0)') || 0
        scores << (avg_accuracy * 100).round
      end

      # Session count progress (attending sessions = progress)
      session_count = @student.tutoring_sessions
        .where(subject: @goal.subject)
        .where('created_at > ?', @goal.created_at)
        .count
      session_progress = [session_count * 15, 50].min # Cap at 50% from sessions alone
      scores << session_progress

      # Calculate weighted average
      return @goal.progress_percentage if scores.empty?
      scores.sum / scores.length
    end

    def gather_completion_signals
      {
        goal: {
          title: @goal.title,
          description: @goal.description,
          target_outcome: @goal.target_outcome,
          subject: @goal.subject
        },
        practice_stats: practice_statistics,
        session_summaries: recent_session_summaries,
        learning_profile: learning_profile_summary,
        milestones_completed: completed_milestones
      }
    end

    def practice_statistics
      practices = @student.practice_sessions
        .where(subject: @goal.subject)
        .where('created_at > ?', @goal.created_at)

      return {} if practices.empty?

      {
        total_sessions: practices.count,
        average_accuracy: practices.average('correct_answers::float / NULLIF(total_problems, 0)')&.round(2),
        total_problems_attempted: practices.sum(:total_problems),
        recent_accuracy_trend: calculate_accuracy_trend(practices)
      }
    end

    def calculate_accuracy_trend(practices)
      recent = practices.order(created_at: :desc).limit(5)
      older = practices.order(created_at: :desc).offset(5).limit(5)

      return 'stable' if recent.count < 3 || older.count < 3

      recent_avg = recent.average('correct_answers::float / NULLIF(total_problems, 0)') || 0
      older_avg = older.average('correct_answers::float / NULLIF(total_problems, 0)') || 0

      if recent_avg > older_avg + 0.1
        'improving'
      elsif recent_avg < older_avg - 0.1
        'declining'
      else
        'stable'
      end
    end

    def recent_session_summaries
      @student.tutoring_sessions
        .where(subject: @goal.subject)
        .where('created_at > ?', @goal.created_at)
        .order(created_at: :desc)
        .limit(5)
        .pluck(:summary)
        .compact
    end

    def learning_profile_summary
      profile = @student.learning_profiles.find_by(subject: @goal.subject)
      return {} unless profile

      {
        proficiency_level: profile.proficiency_level,
        strengths: profile.strengths,
        weaknesses: profile.weaknesses
      }
    end

    def completed_milestones
      (@goal.milestones || []).select { |m| m['completed'] }
    end

    def ai_evaluate_completion(signals)
      client = OpenAI::Client.new

      prompt = <<~PROMPT
        Evaluate if a student has completed their learning goal:

        Goal: #{signals[:goal][:title]}
        Description: #{signals[:goal][:description]}
        Target Outcome: #{signals[:goal][:target_outcome]}
        Subject: #{signals[:goal][:subject]}

        Practice Statistics:
        #{signals[:practice_stats].to_json}

        Recent Session Summaries:
        #{signals[:session_summaries].join("\n")}

        Learning Profile:
        #{signals[:learning_profile].to_json}

        Milestones Completed: #{signals[:milestones_completed].length}

        Respond in JSON:
        {
          "is_complete": true/false,
          "estimated_progress": 0-100,
          "reasoning": "brief explanation",
          "remaining_gaps": ["any remaining areas to work on"]
        }
      PROMPT

      response = client.chat(
        parameters: {
          model: 'gpt-4-turbo-preview',
          messages: [{ role: 'user', content: prompt }],
          response_format: { type: 'json_object' }
        }
      )

      JSON.parse(response.dig('choices', 0, 'message', 'content')).with_indifferent_access
    end

    def complete_goal!
      @goal.update!(
        status: :completed,
        completed_at: Time.current
      )

      # Generate next goal suggestions
      generate_next_goal_suggestions!

      # Trigger celebration and retention flow
      GoalCompletionJob.perform_later(@goal.id)
    end

    def generate_next_goal_suggestions!
      recommendations = SubjectRecommendations.get_recommendations(@goal.subject)

      suggestions = recommendations[:next_subjects].map do |subject|
        {
          subject: subject,
          reason: generate_suggestion_reason(subject),
          priority: recommendations[:priority_order].index(subject) || 99
        }
      end.sort_by { |s| s[:priority] }

      @goal.update!(suggested_next_goals: suggestions)
    end

    def generate_suggestion_reason(subject)
      # Could be enhanced with AI for personalized reasons
      "Based on your progress in #{@goal.subject}, #{subject.humanize} is a natural next step."
    end
  end
end


