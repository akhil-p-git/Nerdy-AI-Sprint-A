module Api
  module V1
    module Parent
      class DashboardController < BaseController
        # GET /api/v1/parent/dashboard
        def index
          students_data = current_parent.students.map do |student|
            {
              id: student.id,
              name: "#{student.first_name} #{student.last_name}",
              summary: student_summary(student),
              recent_activity: recent_activity(student),
              goals: active_goals(student),
              recommendations: recommendations(student)
            }
          end

          render json: { students: students_data }
        end

        # GET /api/v1/parent/dashboard/student/:id
        def student_detail
          student = current_parent.students.find(params[:id])

          render json: {
            student: {
              id: student.id,
              name: "#{student.first_name} #{student.last_name}",
              summary: student_summary(student),
              weekly_report: weekly_report(student),
              learning_profiles: learning_profiles(student),
              goals: all_goals(student),
              activity_timeline: activity_timeline(student),
              tutor_sessions: upcoming_sessions(student)
            }
          }
        end

        # GET /api/v1/parent/dashboard/weekly_report/:student_id
        def weekly_report_detail
          student = current_parent.students.find(params[:student_id])

          render json: generate_weekly_report(student)
        end

        private

        def student_summary(student)
          {
            total_sessions_this_month: student.tutoring_sessions.where('created_at > ?', 30.days.ago).count,
            practice_problems_this_week: student.practice_sessions.where('created_at > ?', 7.days.ago).sum(:total_problems),
            average_accuracy: calculate_accuracy(student),
            active_goals: student.learning_goals.where(status: :active).count,
            current_streak: calculate_streak(student),
            engagement_score: calculate_engagement(student)
          }
        end

        def recent_activity(student, limit: 5)
          activities = []

          student.practice_sessions.order(created_at: :desc).limit(limit).each do |ps|
            activities << {
              type: 'practice',
              description: "#{ps.subject} practice: #{ps.correct_answers}/#{ps.total_problems} correct",
              timestamp: ps.created_at
            }
          end

          student.tutoring_sessions.order(created_at: :desc).limit(limit).each do |ts|
            activities << {
              type: 'session',
              description: "#{ts.subject} session with #{ts.tutor&.first_name || 'tutor'}",
              timestamp: ts.started_at
            }
          end

          activities.sort_by { |a| a[:timestamp] }.reverse.first(limit)
        end

        def active_goals(student)
          student.learning_goals.where(status: :active).map do |goal|
            {
              id: goal.id,
              title: goal.title,
              subject: goal.subject,
              progress: goal.progress_percentage,
              target_date: goal.target_date
            }
          end
        end

        def recommendations(student)
          recs = []

          # Low engagement
          tracker = Retention::EngagementTracker.new(student: student)
          if tracker.engagement_score < 50
            recs << {
              type: 'engagement',
              priority: 'high',
              message: "#{student.first_name}'s engagement has dropped. Consider scheduling a tutoring session.",
              action: 'book_session'
            }
          end

          # Stalled goals
          stalled = student.learning_goals.where(status: :active).where('updated_at < ?', 14.days.ago)
          if stalled.any?
            recs << {
              type: 'goal_stalled',
              priority: 'medium',
              message: "#{student.first_name} hasn't made progress on '#{stalled.first.title}' in 2 weeks.",
              action: 'view_goal',
              goal_id: stalled.first.id
            }
          end

          # Struggling topics
          profile = student.learning_profiles.order(proficiency_level: :asc).first
          if profile && profile.weaknesses&.any?
            recs << {
              type: 'weakness',
              priority: 'low',
              message: "#{student.first_name} could use help with #{profile.weaknesses.first} in #{profile.subject}.",
              action: 'book_session',
              subject: profile.subject
            }
          end

          recs
        end

        def weekly_report(student)
          week_start = 1.week.ago.beginning_of_week

          {
            period: "#{week_start.strftime('%b %d')} - #{Date.current.strftime('%b %d')}",
            sessions_attended: student.tutoring_sessions.where('started_at > ?', week_start).count,
            practice_problems: student.practice_sessions.where('created_at > ?', week_start).sum(:total_problems),
            accuracy: weekly_accuracy(student, week_start),
            time_spent_minutes: weekly_time_spent(student, week_start),
            goals_progress: goals_progress_this_week(student, week_start),
            highlights: weekly_highlights(student, week_start)
          }
        end

        def learning_profiles(student)
          student.learning_profiles.map do |p|
            {
              subject: p.subject,
              proficiency_level: p.proficiency_level,
              strengths: p.strengths || [],
              weaknesses: p.weaknesses || []
            }
          end
        end

        def all_goals(student)
          student.learning_goals.order(created_at: :desc).map do |g|
            {
              id: g.id,
              title: g.title,
              subject: g.subject,
              status: g.status,
              progress: g.progress_percentage,
              target_date: g.target_date,
              created_at: g.created_at,
              completed_at: g.completed_at
            }
          end
        end

        def activity_timeline(student, limit: 20)
          activities = []

          student.practice_sessions.order(created_at: :desc).limit(limit).each do |ps|
            activities << {
              type: 'practice',
              subject: ps.subject,
              details: "#{ps.correct_answers}/#{ps.total_problems} correct (#{((ps.correct_answers.to_f / ps.total_problems) * 100).round}%)",
              timestamp: ps.created_at
            }
          end

          student.tutoring_sessions.order(created_at: :desc).limit(limit).each do |ts|
            activities << {
              type: 'session',
              subject: ts.subject,
              details: ts.summary || "Session with #{ts.tutor&.first_name}",
              timestamp: ts.started_at
            }
          end

          student.learning_goals.where(status: :completed).each do |g|
            activities << {
              type: 'goal_completed',
              subject: g.subject,
              details: "Completed: #{g.title}",
              timestamp: g.completed_at
            }
          end

          activities.sort_by { |a| a[:timestamp] }.reverse.first(limit)
        end

        def upcoming_sessions(student)
          # Would integrate with Nerdy booking system
          []
        end

        def calculate_accuracy(student)
          sessions = student.practice_sessions.where('created_at > ?', 30.days.ago)
          return 0 if sessions.empty? || sessions.sum(:total_problems).zero?

          ((sessions.sum(:correct_answers).to_f / sessions.sum(:total_problems)) * 100).round
        end

        def calculate_streak(student)
          # Simplified streak calculation
          dates = student.practice_sessions.pluck(:created_at).map(&:to_date).uniq.sort.reverse
          return 0 if dates.empty? || dates.first != Date.current

          streak = 1
          dates.each_cons(2) do |current, previous|
            break unless current - previous == 1
            streak += 1
          end
          streak
        end

        def calculate_engagement(student)
          Retention::EngagementTracker.new(student: student).engagement_score
        end

        def weekly_accuracy(student, week_start)
          sessions = student.practice_sessions.where('created_at > ?', week_start)
          return 0 if sessions.empty? || sessions.sum(:total_problems).zero?

          ((sessions.sum(:correct_answers).to_f / sessions.sum(:total_problems)) * 100).round
        end

        def weekly_time_spent(student, week_start)
          practice_time = student.practice_sessions.where('created_at > ?', week_start).sum(:time_spent_seconds) / 60

          session_time = student.tutoring_sessions.where('started_at > ?', week_start).sum do |s|
            next 0 unless s.started_at && s.ended_at
            ((s.ended_at - s.started_at) / 60).round
          end

          practice_time + session_time
        end

        def goals_progress_this_week(student, week_start)
          student.learning_goals.where(status: :active).map do |g|
            # Get progress change this week (simplified)
            {
              title: g.title,
              current_progress: g.progress_percentage,
              change: rand(5..15) # Would calculate actual change
            }
          end
        end

        def weekly_highlights(student, week_start)
          highlights = []

          # Best practice session
          best = student.practice_sessions.where('created_at > ?', week_start).order(Arel.sql('correct_answers::float / NULLIF(total_problems, 0) DESC')).first
          if best
            accuracy = ((best.correct_answers.to_f / best.total_problems) * 100).round
            highlights << "Best practice session: #{accuracy}% accuracy in #{best.subject}"
          end

          # Goal completed
          completed = student.learning_goals.where(status: :completed).where('completed_at > ?', week_start).first
          highlights << "Completed goal: #{completed.title}" if completed

          # New session
          session = student.tutoring_sessions.where('started_at > ?', week_start).first
          highlights << "Had a #{session.subject} tutoring session" if session

          highlights
        end

        def generate_weekly_report(student)
          week_start = 1.week.ago.beginning_of_week
          report = weekly_report(student)

          # Generate AI summary
          client = OpenAI::Client.new
          prompt = <<~PROMPT
            Generate a brief, encouraging weekly report summary for a parent about their child's learning progress.

            Student: #{student.first_name}
            Sessions this week: #{report[:sessions_attended]}
            Practice problems: #{report[:practice_problems]}
            Average accuracy: #{report[:accuracy]}%
            Time spent: #{report[:time_spent_minutes]} minutes

            Highlights:
            #{report[:highlights].join("\n")}

            Write 2-3 sentences summarizing the week and 1 sentence of encouragement.
          PROMPT

          response = client.chat(
            parameters: {
              model: 'gpt-4-turbo-preview',
              messages: [{ role: 'user', content: prompt }],
              max_tokens: 200
            }
          )

          report[:ai_summary] = response.dig('choices', 0, 'message', 'content')
          report
        end
      end
    end
  end
end


