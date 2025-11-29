module Api
  module V1
    class ActivitiesController < ApplicationController
      # GET /api/v1/activities
      def index
        limit = params[:limit]&.to_i || 20

        activities = []

        # Practice sessions
        current_student.practice_sessions.order(created_at: :desc).limit(limit).each do |ps|
          activities << {
            id: "practice_#{ps.id}",
            type: 'practice_completed',
            description: "Completed #{ps.subject} practice with #{ps.correct_answers}/#{ps.total_problems} correct",
            created_at: ps.created_at
          }
        end

        # Tutoring sessions
        current_student.tutoring_sessions.order(created_at: :desc).limit(limit).each do |ts|
          activities << {
            id: "session_#{ts.id}",
            type: 'session_completed',
            description: "Had a #{ts.subject} session#{ts.tutor ? " with #{ts.tutor.first_name}" : ''}",
            created_at: ts.created_at
          }
        end

        # Conversations
        current_student.conversations.order(updated_at: :desc).limit(limit).each do |c|
          activities << {
            id: "conversation_#{c.id}",
            type: 'conversation',
            description: "AI chat about #{c.subject || 'general topics'}",
            created_at: c.updated_at
          }
        end

        # Goal completions
        current_student.learning_goals.where(status: :completed).order(completed_at: :desc).limit(limit).each do |g|
          activities << {
            id: "goal_#{g.id}",
            type: 'goal_completed',
            description: "Completed goal: #{g.title}",
            created_at: g.completed_at
          }
        end

        # Sort and limit
        activities = activities.sort_by { |a| a[:created_at] }.reverse.first(limit)

        render json: activities
      end
    end
  end
end


