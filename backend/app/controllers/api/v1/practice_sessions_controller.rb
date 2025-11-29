module Api
  module V1
    class PracticeSessionsController < ApplicationController
      before_action :set_session, only: [:show, :submit_answer, :complete]

      # GET /api/v1/practice_sessions
      def index
        sessions = current_student.practice_sessions
          .order(created_at: :desc)
          .limit(50)

        render json: sessions.map { |s| PracticeSessionSerializer.new(s) }
      end

      # POST /api/v1/practice_sessions
      def create
        service = AI::PracticeService.new(student: current_student)

        session = service.generate_session(
          subject: params[:subject],
          session_type: params[:session_type] || 'quiz',
          num_problems: params[:num_problems] || 10,
          goal: params[:goal_id] ? current_student.learning_goals.find(params[:goal_id]) : nil
        )

        render json: PracticeSessionSerializer.new(session, include_problems: true), status: :created
      end

      # GET /api/v1/practice_sessions/:id
      def show
        render json: PracticeSessionSerializer.new(@session, include_problems: true)
      end

      # POST /api/v1/practice_sessions/:id/submit
      def submit_answer
        service = AI::PracticeService.new(student: current_student)
        result = service.submit_answer(params[:problem_id], params[:answer])

        render json: result
      end

      # POST /api/v1/practice_sessions/:id/complete
      def complete
        service = AI::PracticeService.new(student: current_student)
        result = service.complete_session(@session.id)

        render json: result
      end

      # GET /api/v1/practice_sessions/review
      def review
        service = AI::PracticeService.new(student: current_student)
        problems = service.get_next_review_problems(
          subject: params[:subject],
          limit: params[:limit] || 5
        )

        render json: problems
      end

      private

      def set_session
        @session = current_student.practice_sessions.find(params[:id])
      end
    end
  end
end

