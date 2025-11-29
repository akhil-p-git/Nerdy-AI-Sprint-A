class MessageSerializer
  def initialize(message)
    @message = message
  end

  def as_json(*)
    {
      id: @message.id,
      conversation_id: @message.conversation_id,
      role: @message.role,
      content: @message.content,
      created_at: @message.created_at
    }
  end
end

