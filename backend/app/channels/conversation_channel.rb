class ConversationChannel < ApplicationCable::Channel
  def subscribed
    @conversation = Conversation.find(params[:conversation_id])
    stream_for @conversation
  end

  def unsubscribed
    stop_all_streams
  end

  def send_message(data)
    service = AI::ConversationService.new(
      student: current_student,
      conversation: @conversation
    )

    # Broadcast streaming chunks
    service.send_message(data['content'], subject: data['subject'], stream: true) do |chunk|
      ConversationChannel.broadcast_to(@conversation, {
        type: 'chunk',
        content: chunk
      })
    end

    # Broadcast completion
    ConversationChannel.broadcast_to(@conversation, {
      type: 'complete',
      conversation_id: @conversation.id
    })
  end
end

