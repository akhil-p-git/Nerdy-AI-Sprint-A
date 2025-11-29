module Api
  module V1
    class ConversationsController < ApplicationController
      before_action :set_conversation, only: [:show, :messages, :send_message]

      # GET /api/v1/conversations
      def index
        conversations = current_student.conversations
          .order(updated_at: :desc)
          .limit(50)

        render json: conversations.map { |c| ConversationSerializer.new(c) }
      end

      # POST /api/v1/conversations
      def create
        service = AI::ConversationService.new(student: current_student)
        conversation = service.conversation

        if params[:initial_message].present?
          service.send_message(
            params[:initial_message],
            subject: params[:subject]
          )
        end

        render json: ConversationSerializer.new(conversation), status: :created
      end

      # GET /api/v1/conversations/:id
      def show
        render json: ConversationSerializer.new(@conversation, include_messages: true)
      end

      # POST /api/v1/conversations/:id/messages
      def send_message
        service = AI::ConversationService.new(
          student: current_student,
          conversation: @conversation
        )

        message = service.send_message(
          params[:content],
          subject: params[:subject]
        )

        render json: MessageSerializer.new(message)
      end

      private

      def set_conversation
        @conversation = current_student.conversations.find(params[:id])
      end
    end
  end
end

