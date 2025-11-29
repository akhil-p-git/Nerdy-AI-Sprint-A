module Api
  module V1
    class LearningGoalsController < ApplicationController
      before_action :set_goal, only: [:show, :update, :destroy, :suggestions, :evaluate_completion]

      # GET /api/v1/learning_goals
      def index
        goals = current_student.learning_goals

        # Filter by status
        goals = goals.where(status: params[:status]) if params[:status].present?

        # Filter by subject
        goals = goals.where(subject: params[:subject]) if params[:subject].present?

        goals = goals.order(created_at: :desc)

        render json: goals.map { |g| LearningGoalSerializer.new(g) }
      end

      # GET /api/v1/learning_goals/:id
      def show
        render json: LearningGoalSerializer.new(@goal, detailed: true)
      end

      # POST /api/v1/learning_goals
      def create
        goal = current_student.learning_goals.build(goal_params)
        goal.status = :active

        if goal.save
          render json: LearningGoalSerializer.new(goal), status: :created
        else
          render json: { errors: goal.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # PUT /api/v1/learning_goals/:id
      def update
        if @goal.update(goal_params)
          render json: LearningGoalSerializer.new(@goal)
        else
          render json: { errors: @goal.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/learning_goals/:id
      def destroy
        @goal.destroy
        head :no_content
      end

      # GET /api/v1/learning_goals/:id/suggestions
      def suggestions
        recommendations = Retention::SubjectRecommendations.get_recommendations(@goal.subject)

        render json: {
          completed_goal: @goal.title,
          message: recommendations[:message],
          suggestions: recommendations[:next_subjects].map do |subject|
            {
              subject: subject,
              reason: "Based on your progress in #{@goal.subject}",
              priority: recommendations[:priority_order].index(subject) || 99
            }
          end.sort_by { |s| s[:priority] }
        }
      end

      # POST /api/v1/learning_goals/:id/evaluate_completion
      def evaluate_completion
        service = Retention::GoalProgressService.new(goal: @goal)
        evaluation = service.evaluate_completion

        render json: evaluation
      end

      # POST /api/v1/learning_goals/:id/milestones
      def add_milestone
        @goal = current_student.learning_goals.find(params[:id])
        milestones = @goal.milestones || []

        milestones << {
          id: SecureRandom.uuid,
          title: params[:title],
          completed: false,
          created_at: Time.current
        }

        @goal.update!(milestones: milestones)
        render json: LearningGoalSerializer.new(@goal)
      end

      # PUT /api/v1/learning_goals/:id/milestones/:milestone_id
      def update_milestone
        @goal = current_student.learning_goals.find(params[:id])
        milestones = @goal.milestones || []

        milestone = milestones.find { |m| m['id'] == params[:milestone_id] }
        if milestone
          milestone['completed'] = params[:completed]
          milestone['completed_at'] = Time.current if params[:completed]
          @goal.update!(milestones: milestones)

          # Recalculate progress
          completed_count = milestones.count { |m| m['completed'] }
          progress = (completed_count.to_f / milestones.length * 100).round
          @goal.update!(progress_percentage: progress)
        end

        render json: LearningGoalSerializer.new(@goal)
      end

      private

      def set_goal
        @goal = current_student.learning_goals.find(params[:id])
      end

      def goal_params
        params.permit(:subject, :title, :description, :target_outcome, :target_date, :status, :progress_percentage)
      end
    end
  end
end


