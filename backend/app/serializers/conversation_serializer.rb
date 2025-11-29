class ConversationSerializer
  def initialize(conversation, include_messages: false)
    @conversation = conversation
    @include_messages = include_messages
  end

  def as_json(*)
    data = {
      id: @conversation.id,
      subject: @conversation.subject,
      status: @conversation.status,
      created_at: @conversation.created_at,
      updated_at: @conversation.updated_at,
      message_count: @conversation.messages.count,
      last_message: last_message_preview
    }

    data[:messages] = @conversation.messages.order(:created_at).map do |m|
      MessageSerializer.new(m).as_json
    end if @include_messages

    data
  end

  private

  def last_message_preview
    msg = @conversation.messages.order(created_at: :desc).first
    return nil unless msg

    {
      role: msg.role,
      preview: msg.content.truncate(100),
      created_at: msg.created_at
    }
  end
end

