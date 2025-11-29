module Api
  module V1
    class StatsController < ApplicationController
      # GET /api/v1/stats
      def index
        stats = {
          total_sessions: current_student.tutoring_sessions.count,
          total_practice_problems: total_practice_problems,
          average_accuracy: average_accuracy,
          current_streak: calculate_streak,
          goals_completed: current_student.learning_goals.where(status: :completed).count,
          active_goals: current_student.learning_goals.where(status: :active).count,
          total_conversation_messages: total_messages,
          time_spent_minutes: calculate_time_spent
        }

        render json: stats
      end

      # GET /api/v1/stats/weekly
      def weekly
        weeks = 8
        data = (0...weeks).map do |i|
          week_start = i.weeks.ago.beginning_of_week
          week_end = i.weeks.ago.end_of_week

          {
            week: week_start.strftime('%b %d'),
            sessions: current_student.tutoring_sessions.where(created_at: week_start..week_end).count,
            practice_problems: current_student.practice_sessions.where(created_at: week_start..week_end).sum(:total_problems),
            accuracy: weekly_accuracy(week_start, week_end)
          }
        end.reverse

        render json: data
      end

      private

      def total_practice_problems
        current_student.practice_sessions.sum(:total_problems)
      end

      def average_accuracy
        sessions = current_student.practice_sessions.where('total_problems > 0')
        return 0 if sessions.empty?

        total_correct = sessions.sum(:correct_answers)
        total_problems = sessions.sum(:total_problems)
        ((total_correct.to_f / total_problems) * 100).round
      end

      def calculate_streak
        dates = current_student.practice_sessions
          .or(current_student.conversations.where('updated_at > created_at'))
          .pluck(:created_at)
          .map(&:to_date)
          .uniq
          .sort
          .reverse

        return 0 if dates.empty?

        streak = 0
        current_date = Date.current

        dates.each do |date|
          if date == current_date || date == current_date - streak.days
            streak += 1
            current_date = date
          else
            break
          end
        end

        streak
      end

      def total_messages
        Message.joins(:conversation)
          .where(conversations: { student_id: current_student.id })
          .count
      end

      def calculate_time_spent
        # Estimate based on sessions and practice
        session_minutes = current_student.tutoring_sessions.sum do |s|
          next 0 unless s.started_at && s.ended_at
          ((s.ended_at - s.started_at) / 60).round
        end

        practice_minutes = current_student.practice_sessions.sum(:time_spent_seconds) / 60

        session_minutes + practice_minutes
      end

      def weekly_accuracy(week_start, week_end)
        sessions = current_student.practice_sessions
          .where(created_at: week_start..week_end)
          .where('total_problems > 0')

        return 0 if sessions.empty?

        total_correct = sessions.sum(:correct_answers)
        total_problems = sessions.sum(:total_problems)
        ((total_correct.to_f / total_problems) * 100).round
      end
    end
  end
end


