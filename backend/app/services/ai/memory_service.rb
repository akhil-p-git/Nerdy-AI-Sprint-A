module AI
  class MemoryService
    EMBEDDING_MODEL = 'text-embedding-3-small'
    EMBEDDING_DIMENSIONS = 1536

    def initialize(student:)
      @student = student
      @client = OpenAI::Client.new
    end

    # Store new knowledge/interaction in memory
    def store_interaction(content:, topic:, source_type:, source_id:, metadata: {})
      embedding = generate_embedding(content)

      KnowledgeNode.create!(
        student: @student,
        content: content,
        topic: topic,
        subject: detect_subject(content),
        source_type: source_type,
        source_id: source_id,
        embedding: embedding,
        metadata: metadata
      )
    end

    # Store session summary in memory
    def store_session_summary(session:, summary:, key_concepts:)
      content = <<~TEXT
        Session with #{session.tutor&.first_name || 'tutor'} on #{session.subject}:
        #{summary}

        Key concepts covered:
        #{key_concepts.join(', ')}
      TEXT

      store_interaction(
        content: content,
        topic: session.subject,
        source_type: 'session',
        source_id: session.id,
        metadata: { key_concepts: key_concepts }
      )
    end

    # Retrieve relevant context using semantic search
    def retrieve_relevant_context(query, limit: 5, min_similarity: 0.7)
      query_embedding = generate_embedding(query)

      # Use pgvector's cosine distance operator
      KnowledgeNode
        .where(student: @student)
        .select("*, (embedding <=> '#{query_embedding}') as distance")
        .where("(embedding <=> '#{query_embedding}') < ?", 1 - min_similarity)
        .order(Arel.sql("embedding <=> '#{query_embedding}'"))
        .limit(limit)
    end

    # Get recent context for a subject
    def get_subject_context(subject, limit: 10)
      @student.knowledge_nodes
        .where(subject: subject)
        .order(created_at: :desc)
        .limit(limit)
    end

    # Build a knowledge summary for a topic
    def summarize_knowledge(topic)
      nodes = @student.knowledge_nodes
        .where("topic ILIKE ?", "%#{topic}%")
        .order(created_at: :desc)
        .limit(20)

      return nil if nodes.empty?

      # Use AI to summarize
      prompt = <<~PROMPT
        Summarize the following learning history for a student on the topic "#{topic}":

        #{nodes.map(&:content).join("\n\n---\n\n")}

        Provide a concise summary of:
        1. What the student has learned
        2. Key concepts they understand
        3. Areas they may need to review
      PROMPT

      response = @client.chat(
        parameters: {
          model: 'gpt-4-turbo-preview',
          messages: [{ role: 'user', content: prompt }],
          max_tokens: 500
        }
      )

      response.dig('choices', 0, 'message', 'content')
    end

    # Identify knowledge gaps
    def identify_knowledge_gaps(subject)
      # Get practice history
      practice_sessions = @student.practice_sessions
        .where(subject: subject)
        .where('created_at > ?', 30.days.ago)
        .includes(:practice_problems)

      struggled_topics = practice_sessions.flat_map(&:struggled_topics).uniq

      # Get conversation patterns (questions asked multiple times)
      frequent_questions = Message
        .joins(:conversation)
        .where(conversations: { student_id: @student.id })
        .where(role: 'user')
        .where('messages.created_at > ?', 30.days.ago)
        .group(:content)
        .having('COUNT(*) > 1')
        .pluck(:content)

      {
        struggled_topics: struggled_topics,
        repeated_questions: frequent_questions,
        suggested_review: struggled_topics.first(5)
      }
    end

    private

    def generate_embedding(text)
      response = @client.embeddings(
        parameters: {
          model: EMBEDDING_MODEL,
          input: text.truncate(8000)
        }
      )

      response.dig('data', 0, 'embedding')
    end

    def detect_subject(content)
      subjects = {
        'mathematics' => /\b(math|algebra|calculus|geometry|equation|derivative|integral)\b/i,
        'physics' => /\b(physics|velocity|force|energy|momentum|newton)\b/i,
        'chemistry' => /\b(chemistry|molecule|atom|reaction|element|compound)\b/i,
        'biology' => /\b(biology|cell|dna|evolution|organism|genetics)\b/i,
        'english' => /\b(grammar|essay|literature|writing|vocabulary|reading)\b/i,
        'history' => /\b(history|war|civilization|revolution|empire)\b/i,
        'sat_prep' => /\b(sat|act|test prep|college board|practice test)\b/i
      }

      subjects.find { |_, pattern| content.match?(pattern) }&.first || 'general'
    end
  end
end

