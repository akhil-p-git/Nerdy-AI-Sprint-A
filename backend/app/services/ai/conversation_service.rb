module AI
  class ConversationService
    MAX_CONTEXT_TOKENS = 12000
    MODEL = 'gpt-4-turbo-preview'

    def initialize(student:, conversation: nil)
      @student = student
      @conversation = conversation || create_conversation
      @client = OpenAI::Client.new
      @memory_service = MemoryService.new(student: student)
    end

    attr_reader :conversation

    def send_message(content, subject: nil, stream: false, &block)
      # Store user message
      user_message = create_message(role: 'user', content: content)

      # Build context-aware prompt
      system_prompt = build_system_prompt(subject)
      context = @memory_service.retrieve_relevant_context(content, limit: 5)
      messages = build_messages(system_prompt, context, content)

      if stream
        stream_response(messages, &block)
      else
        generate_response(messages)
      end
    end

    private

    def create_conversation
      Conversation.create!(
        student: @student,
        subject: nil,
        status: 'active'
      )
    end

    def create_message(role:, content:, metadata: {})
      Message.create!(
        conversation: @conversation,
        role: role,
        content: content,
        metadata: metadata
      )
    end

    def build_system_prompt(subject)
      <<~PROMPT
        You are an expert AI tutor for #{subject || 'academic subjects'}. You help students learn effectively by:

        1. **Understanding First**: Always ensure you understand what the student is asking before answering.
        2. **Socratic Method**: When appropriate, guide students to discover answers through questions.
        3. **Clear Explanations**: Break down complex concepts into digestible pieces.
        4. **Examples**: Use relevant, relatable examples to illustrate points.
        5. **Encouragement**: Be supportive and encouraging, celebrating progress.
        6. **Adaptive**: Adjust your explanations based on the student's level.

        Student Profile:
        - Name: #{@student.first_name}
        - Current subject focus: #{subject || 'General'}

        Guidelines:
        - If the student seems frustrated, acknowledge it and offer a different approach.
        - If you detect a knowledge gap, note it for future reference.
        - If a question is beyond your ability to help effectively, suggest booking a session with a human tutor.
        - Use markdown for formatting (headers, bullet points, code blocks).
        - For math, use LaTeX notation wrapped in $ symbols.

        Remember: Your goal is to help the student LEARN, not just give answers.
      PROMPT
    end

    def build_messages(system_prompt, context, current_message)
      messages = [{ role: 'system', content: system_prompt }]

      # Add relevant context from memory
      if context.present?
        context_text = context.map do |node|
          "Previous learning context (#{node.topic}): #{node.content}"
        end.join("\n\n")

        messages << {
          role: 'system',
          content: "Relevant context from student's learning history:\n#{context_text}"
        }
      end

      # Add conversation history (with token limit)
      history = @conversation.messages.order(created_at: :desc).limit(20).reverse
      history.each do |msg|
        messages << { role: msg.role, content: msg.content }
      end

      # Add current message
      messages << { role: 'user', content: current_message }

      # Trim to fit context window
      trim_messages_to_token_limit(messages)
    end

    def trim_messages_to_token_limit(messages)
      encoder = Tiktoken.encoding_for_model(MODEL)
      total_tokens = messages.sum { |m| encoder.encode(m[:content]).length }

      while total_tokens > MAX_CONTEXT_TOKENS && messages.length > 3
        # Remove oldest non-system message
        removed = messages.delete_at(2)
        total_tokens -= encoder.encode(removed[:content]).length
      end

      messages
    end

    def generate_response(messages)
      response = @client.chat(
        parameters: {
          model: MODEL,
          messages: messages,
          temperature: 0.7,
          max_tokens: 2000
        }
      )

      content = response.dig('choices', 0, 'message', 'content')
      assistant_message = create_message(
        role: 'assistant',
        content: content,
        metadata: { model: MODEL, tokens: response['usage'] }
      )

      # Store in memory for future context
      @memory_service.store_interaction(
        content: "Q: #{messages.last[:content]}\nA: #{content}",
        topic: detect_topic(messages.last[:content]),
        source_type: 'conversation',
        source_id: @conversation.id
      )

      assistant_message
    end

    def stream_response(messages, &block)
      full_response = ''

      @client.chat(
        parameters: {
          model: MODEL,
          messages: messages,
          temperature: 0.7,
          max_tokens: 2000,
          stream: proc do |chunk, _bytesize|
            content = chunk.dig('choices', 0, 'delta', 'content')
            if content
              full_response += content
              block.call(content) if block_given?
            end
          end
        }
      )

      # Store complete response
      assistant_message = create_message(
        role: 'assistant',
        content: full_response,
        metadata: { model: MODEL, streamed: true }
      )

      @memory_service.store_interaction(
        content: "Q: #{messages.last[:content]}\nA: #{full_response}",
        topic: detect_topic(messages.last[:content]),
        source_type: 'conversation',
        source_id: @conversation.id
      )

      assistant_message
    end

    def detect_topic(content)
      # Simple topic detection - can be enhanced with AI
      topics = {
        'math' => /\b(equation|algebra|calculus|geometry|math|solve|calculate)\b/i,
        'science' => /\b(physics|chemistry|biology|science|experiment|hypothesis)\b/i,
        'english' => /\b(grammar|essay|writing|literature|reading|vocabulary)\b/i,
        'history' => /\b(history|war|civilization|century|historical)\b/i,
        'sat' => /\b(sat|act|test prep|college board)\b/i
      }

      topics.find { |_, pattern| content.match?(pattern) }&.first || 'general'
    end
  end
end

