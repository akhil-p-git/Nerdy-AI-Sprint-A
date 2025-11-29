module Api
  module V1
    class TutorBriefsController < ApplicationController
      skip_before_action :authenticate_request
      before_action :authenticate_tutor

      # GET /api/v1/tutor_briefs
      def index
        briefs = TutorBrief
          .where(tutor: @current_tutor)
          .where('session_datetime > ?', Time.current)
          .order(session_datetime: :asc)

        render json: briefs.map { |b| TutorBriefSerializer.new(b) }
      end

      # GET /api/v1/tutor_briefs/:id
      def show
        brief = TutorBrief.find(params[:id])

        # Mark as viewed
        brief.update!(viewed: true, viewed_at: Time.current) unless brief.viewed?

        render json: TutorBriefSerializer.new(brief, full: true)
      end

      # POST /api/v1/tutor_briefs/generate
      def generate
        student = Student.find(params[:student_id])

        service = AI::TutorBriefService.new(
          student: student,
          tutor: @current_tutor,
          subject: params[:subject],
          session_datetime: Time.parse(params[:session_datetime])
        )

        brief = service.generate_brief

        render json: { content: brief }, status: :created
      end

      private

      def authenticate_tutor
        token = extract_token
        payload = JwtService.decode(token)

        if payload && payload[:tutor_id]
          @current_tutor = Tutor.find_by(id: payload[:tutor_id])
        end

        render json: { error: 'Unauthorized' }, status: :unauthorized unless @current_tutor
      end

      def extract_token
        header = request.headers['Authorization']
        header&.split(' ')&.last
      end
    end
  end
end


