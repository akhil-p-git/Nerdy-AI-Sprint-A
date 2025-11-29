module Api
  module V1
    class LearningProfilesController < ApplicationController
      before_action :set_profile, only: [:show, :update]

      # GET /api/v1/learning_profiles
      def index
        profiles = current_student.learning_profiles.order(:subject)
        render json: profiles.map { |p| LearningProfileSerializer.new(p) }
      end

      # GET /api/v1/learning_profiles/:id
      def show
        render json: LearningProfileSerializer.new(@profile, detailed: true)
      end

      # PUT /api/v1/learning_profiles/:id
      def update
        if @profile.update(profile_params)
          render json: LearningProfileSerializer.new(@profile)
        else
          render json: { errors: @profile.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # GET /api/v1/learning_profiles/summary
      def summary
        profiles = current_student.learning_profiles

        summary = {
          total_subjects: profiles.count,
          average_proficiency: profiles.average(:proficiency_level)&.round(1) || 0,
          strongest_subject: profiles.order(proficiency_level: :desc).first&.subject,
          weakest_subject: profiles.order(proficiency_level: :asc).first&.subject,
          subjects: profiles.map do |p|
            {
              subject: p.subject,
              proficiency: p.proficiency_level,
              strengths_count: p.strengths&.length || 0,
              weaknesses_count: p.weaknesses&.length || 0
            }
          end
        }

        render json: summary
      end

      private

      def set_profile
        @profile = current_student.learning_profiles.find(params[:id])
      end

      def profile_params
        params.permit(:proficiency_level, strengths: [], weaknesses: [], knowledge_gaps: [])
      end
    end
  end
end


