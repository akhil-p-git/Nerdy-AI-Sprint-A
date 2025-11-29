module AI
  class EscalationDetector
    ESCALATION_TRIGGERS = {
      repeated_confusion: 3,      # Same question asked 3+ times
      frustration_signals: 2,     # 2+ frustration indicators
      complex_topic_threshold: 8, # Difficulty level 8+
      low_confidence_responses: 3 # AI unsure 3+ times
    }.freeze

    FRUSTRATION_PATTERNS = [
      /i don't (understand|get it)/i,
      /this (doesn't|does not) make sense/i,
      /i('m| am) (so )?(confused|lost|frustrated)/i,
      /can you explain (again|differently)/i,
      /i give up/i,
      /this is (too )?hard/i,
      /help me/i,
      /\?{2,}/, # Multiple question marks
      /!{2,}/   # Multiple exclamation marks (frustration)
    ].freeze

    def initialize(conversation:)
      @conversation = conversation
      @student = conversation.student
      @messages = conversation.messages.order(:created_at)
    end

    def should_escalate?
      return true if repeated_confusion?
      return true if frustration_detected?
      return true if topic_too_complex?
      return true if ai_struggling?
      false
    end

    def escalation_reason
      reasons = []
      reasons << 'repeated_confusion' if repeated_confusion?
      reasons << 'student_frustration' if frustration_detected?
      reasons << 'complex_topic' if topic_too_complex?
      reasons << 'ai_limitations' if ai_struggling?
      reasons
    end

    def generate_escalation_context
      {
        conversation_id: @conversation.id,
        student_id: @student.id,
        subject: @conversation.subject,
        reasons: escalation_reason,
        conversation_summary: summarize_conversation,
        student_struggles: identify_struggles,
        recommended_session_focus: recommend_focus_areas,
        urgency: calculate_urgency
      }
    end

    private

    def repeated_confusion?
      user_messages = @messages.where(role: 'user').pluck(:content)
      return false if user_messages.length < 3

      # Check for similar questions
      recent_messages = user_messages.last(5)
      similar_count = count_similar_messages(recent_messages)
      similar_count >= ESCALATION_TRIGGERS[:repeated_confusion]
    end

    def count_similar_messages(messages)
      return 0 if messages.length < 2

      similarities = messages.combination(2).count do |m1, m2|
        similar_content?(m1, m2)
      end

      # Convert combinations to approximate repeat count
      (similarities / 2.0).ceil + 1
    end

    def similar_content?(text1, text2)
      # Simple similarity check - could be enhanced with embeddings
      words1 = text1.downcase.split(/\W+/).to_set
      words2 = text2.downcase.split(/\W+/).to_set

      intersection = words1 & words2
      union = words1 | words2

      return false if union.empty?
      intersection.size.to_f / union.size > 0.5
    end

    def frustration_detected?
      recent_user_messages = @messages.where(role: 'user').last(5)

      frustration_count = recent_user_messages.count do |msg|
        FRUSTRATION_PATTERNS.any? { |pattern| msg.content.match?(pattern) }
      end

      frustration_count >= ESCALATION_TRIGGERS[:frustration_signals]
    end

    def topic_too_complex?
      # Check if we're discussing advanced topics
      profile = @student.learning_profiles.find_by(subject: @conversation.subject)
      return false unless profile

      # If topic difficulty exceeds student level significantly
      current_topic_difficulty = estimate_topic_difficulty
      student_level = profile.proficiency_level

      current_topic_difficulty - student_level >= 3
    end

    def estimate_topic_difficulty
      # Analyze recent messages to estimate difficulty
      recent_content = @messages.last(5).pluck(:content).join(' ')

      advanced_indicators = [
        /theorem|proof|derive|integral|differential/i,
        /synthesis|analysis|evaluate|critique/i,
        /advanced|complex|challenging/i
      ]

      indicator_count = advanced_indicators.count { |i| recent_content.match?(i) }

      base_difficulty = 5
      base_difficulty + (indicator_count * 2)
    end

    def ai_struggling?
      # Check if AI has been giving uncertain responses
      recent_ai_messages = @messages.where(role: 'assistant').last(5)

      uncertain_patterns = [
        /i('m| am) not (entirely )?sure/i,
        /this (might|may) be/i,
        /i think/i,
        /it's possible that/i,
        /you (should|might want to) (ask|consult|check with)/i
      ]

      uncertain_count = recent_ai_messages.count do |msg|
        uncertain_patterns.any? { |pattern| msg.content.match?(pattern) }
      end

      uncertain_count >= ESCALATION_TRIGGERS[:low_confidence_responses]
    end

    def summarize_conversation
      messages_text = @messages.last(10).map do |m|
        "#{m.role}: #{m.content.truncate(200)}"
      end.join("\n")

      client = OpenAI::Client.new
      response = client.chat(
        parameters: {
          model: 'gpt-4-turbo-preview',
          messages: [{
            role: 'user',
            content: "Summarize this tutoring conversation in 2-3 sentences, focusing on what the student is trying to learn and where they're struggling:\n\n#{messages_text}"
          }],
          max_tokens: 150
        }
      )

      response.dig('choices', 0, 'message', 'content')
    end

    def identify_struggles
      user_questions = @messages.where(role: 'user').pluck(:content)

      # Extract topics from questions
      topics = user_questions.flat_map do |q|
        extract_topics(q)
      end.tally.sort_by { |_, count| -count }.first(5).map(&:first)

      topics
    end

    def extract_topics(text)
      # Simple topic extraction - could be enhanced with NER
      text.downcase.scan(/\b(how|what|why|when|where|explain|help with)\s+(.+?)[\?\.]/)
        .map { |_, topic| topic.strip }
    end

    def recommend_focus_areas
      struggles = identify_struggles
      profile = @student.learning_profiles.find_by(subject: @conversation.subject)

      areas = []
      areas += struggles.first(3)
      areas += (profile&.weaknesses || []).first(2)
      areas.uniq.first(5)
    end

    def calculate_urgency
      if frustration_detected? && repeated_confusion?
        'high'
      elsif frustration_detected? || repeated_confusion?
        'medium'
      else
        'low'
      end
    end
  end
end


