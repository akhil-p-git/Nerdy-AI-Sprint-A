# One-Shot Prompt: AI Core Services (Tasks 4, 5, 7)

## Context
Building the AI brain for the Nerdy AI Study Companion. This includes the conversation engine, memory system, and adaptive practice generation. Assumes Tasks 1-3 (project setup, database, auth) are complete.

## Your Mission
Implement the complete AI core in a single pass:
- **Task 4:** AI Conversation Service with streaming
- **Task 5:** Vector Database Memory System
- **Task 7:** Adaptive Practice Engine

---

## Task 4: AI Conversation Service

Build the core conversational AI that answers student questions with context awareness.

### Backend Gems Required
Add to `backend/Gemfile`:
```ruby
gem 'ruby-openai'        # OpenAI API client
gem 'anthropic'          # Claude API client (alternative)
gem 'tiktoken_ruby'      # Token counting
gem 'actioncable'        # Already included, for streaming
```

### AI Configuration
Create `backend/config/initializers/openai.rb`:
```ruby
OpenAI.configure do |config|
  config.access_token = ENV.fetch('OPENAI_API_KEY')
  config.organization_id = ENV.fetch('OPENAI_ORG_ID', nil)
  config.request_timeout = 120
end
```

### Conversation Service
Create `backend/app/services/ai/conversation_service.rb`:
```ruby
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
```

### Streaming Channel (ActionCable)
Create `backend/app/channels/conversation_channel.rb`:
```ruby
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
```

### Connection Authentication
Update `backend/app/channels/application_cable/connection.rb`:
```ruby
module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_student

    def connect
      self.current_student = find_verified_student
    end

    private

    def find_verified_student
      token = request.params[:token]
      payload = JwtService.decode(token)

      if payload && (student = Student.find_by(id: payload[:student_id]))
        student
      else
        reject_unauthorized_connection
      end
    end
  end
end
```

### REST API Controller
Create `backend/app/controllers/api/v1/conversations_controller.rb`:
```ruby
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
```

### Serializers
Create `backend/app/serializers/conversation_serializer.rb`:
```ruby
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
```

Create `backend/app/serializers/message_serializer.rb`:
```ruby
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
```

---

## Task 5: Vector Database Memory System

Implement persistent memory using pgvector for semantic search and context retrieval.

### Enable pgvector
Create migration `backend/db/migrate/xxx_enable_vector_extension.rb`:
```ruby
class EnableVectorExtension < ActiveRecord::Migration[7.0]
  def up
    enable_extension 'vector'
  end

  def down
    disable_extension 'vector'
  end
end
```

### Memory Service
Create `backend/app/services/ai/memory_service.rb`:
```ruby
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
```

### Knowledge Node Model Updates
Update `backend/app/models/knowledge_node.rb`:
```ruby
class KnowledgeNode < ApplicationRecord
  belongs_to :student

  validates :content, presence: true
  validates :embedding, presence: true

  # Scopes
  scope :recent, -> { order(created_at: :desc) }
  scope :by_subject, ->(subject) { where(subject: subject) }
  scope :by_topic, ->(topic) { where("topic ILIKE ?", "%#{topic}%") }

  # Find similar nodes using cosine similarity
  def similar_nodes(limit: 5)
    return [] unless embedding.present?

    KnowledgeNode
      .where(student_id: student_id)
      .where.not(id: id)
      .select("*, (embedding <=> '#{embedding}') as distance")
      .order(Arel.sql("embedding <=> '#{embedding}'"))
      .limit(limit)
  end
end
```

### Session Processing Job
Create `backend/app/jobs/process_session_job.rb`:
```ruby
class ProcessSessionJob < ApplicationJob
  queue_as :default

  def perform(session_id)
    session = TutoringSession.find(session_id)
    return unless session.transcript_url.present?

    # Fetch and process transcript
    transcript = fetch_transcript(session.transcript_url)
    return unless transcript.present?

    # Extract key information using AI
    analysis = analyze_session(transcript, session.subject)

    # Update session with summary
    session.update!(
      summary: analysis[:summary],
      topics_covered: analysis[:topics],
      key_concepts: analysis[:concepts]
    )

    # Store in memory
    memory_service = AI::MemoryService.new(student: session.student)
    memory_service.store_session_summary(
      session: session,
      summary: analysis[:summary],
      key_concepts: analysis[:concepts]
    )

    # Update learning profile
    update_learning_profile(session.student, session.subject, analysis)
  end

  private

  def fetch_transcript(url)
    # Implement transcript fetching from Nerdy platform
    # This is a placeholder
    response = HTTP.get(url)
    response.body.to_s if response.status.success?
  rescue => e
    Rails.logger.error("Failed to fetch transcript: #{e.message}")
    nil
  end

  def analyze_session(transcript, subject)
    client = OpenAI::Client.new

    prompt = <<~PROMPT
      Analyze this tutoring session transcript for #{subject}:

      #{transcript.truncate(10000)}

      Provide a JSON response with:
      {
        "summary": "2-3 sentence summary of what was covered",
        "topics": ["list", "of", "topics"],
        "concepts": ["key", "concepts", "learned"],
        "student_struggles": ["areas", "where", "student", "struggled"],
        "mastery_indicators": ["concepts", "student", "demonstrated", "understanding"]
      }
    PROMPT

    response = client.chat(
      parameters: {
        model: 'gpt-4-turbo-preview',
        messages: [{ role: 'user', content: prompt }],
        response_format: { type: 'json_object' }
      }
    )

    JSON.parse(response.dig('choices', 0, 'message', 'content')).with_indifferent_access
  end

  def update_learning_profile(student, subject, analysis)
    profile = student.learning_profiles.find_or_create_by(subject: subject)

    # Merge new concepts into existing
    existing_strengths = profile.strengths || []
    existing_weaknesses = profile.weaknesses || []

    profile.update!(
      strengths: (existing_strengths + analysis[:mastery_indicators]).uniq.last(20),
      weaknesses: (existing_weaknesses + analysis[:student_struggles]).uniq.last(20),
      last_assessed_at: Time.current
    )
  end
end
```

---

## Task 7: Adaptive Practice Engine

Build AI-powered practice problem generation with spaced repetition.

### Practice Service
Create `backend/app/services/ai/practice_service.rb`:
```ruby
module AI
  class PracticeService
    DIFFICULTY_LEVELS = (1..10).to_a

    def initialize(student:)
      @student = student
      @client = OpenAI::Client.new
      @memory_service = MemoryService.new(student: student)
    end

    # Generate a practice session
    def generate_session(subject:, session_type:, num_problems: 10, goal: nil)
      # Get student's current level
      profile = @student.learning_profiles.find_by(subject: subject)
      current_level = profile&.proficiency_level || 5

      # Get topics to focus on (prioritize weak areas)
      focus_topics = determine_focus_topics(subject, profile)

      # Get relevant context for problem generation
      context = @memory_service.get_subject_context(subject, limit: 5)

      # Generate problems
      problems = generate_problems(
        subject: subject,
        session_type: session_type,
        num_problems: num_problems,
        difficulty: current_level,
        focus_topics: focus_topics,
        context: context
      )

      # Create practice session
      session = PracticeSession.create!(
        student: @student,
        learning_goal: goal,
        subject: subject,
        session_type: session_type,
        total_problems: problems.length
      )

      # Create problems
      problems.each_with_index do |problem_data, index|
        PracticeProblem.create!(
          practice_session: session,
          problem_type: problem_data[:type],
          question: problem_data[:question],
          correct_answer: problem_data[:answer],
          options: problem_data[:options] || [],
          explanation: problem_data[:explanation],
          difficulty_level: problem_data[:difficulty],
          topic: problem_data[:topic]
        )
      end

      session.reload
    end

    # Submit answer and get feedback
    def submit_answer(problem_id, student_answer)
      problem = PracticeProblem.find(problem_id)
      session = problem.practice_session

      # Check answer
      is_correct = check_answer(problem, student_answer)

      # Update problem
      problem.update!(
        student_answer: student_answer,
        is_correct: is_correct
      )

      # Update session stats
      if is_correct
        session.increment!(:correct_answers)
      else
        session.update!(
          struggled_topics: (session.struggled_topics || []) + [problem.topic]
        )
      end

      # Generate feedback
      feedback = generate_feedback(problem, student_answer, is_correct)

      # Adjust difficulty for next problems
      adjust_difficulty(session, is_correct)

      {
        is_correct: is_correct,
        correct_answer: problem.correct_answer,
        explanation: problem.explanation,
        feedback: feedback
      }
    end

    # Get next problem based on spaced repetition
    def get_next_review_problems(subject:, limit: 5)
      # Find problems student got wrong or haven't reviewed in a while
      due_for_review = PracticeProblem
        .joins(:practice_session)
        .where(practice_sessions: { student_id: @student.id, subject: subject })
        .where('practice_problems.is_correct = false OR practice_problems.created_at < ?', spaced_repetition_interval)
        .order(Arel.sql('RANDOM()'))
        .limit(limit)

      due_for_review.map do |problem|
        regenerate_similar_problem(problem)
      end
    end

    # Complete session and update profile
    def complete_session(session_id)
      session = PracticeSession.find(session_id)
      session.update!(completed_at: Time.current)

      # Calculate performance
      accuracy = session.correct_answers.to_f / session.total_problems

      # Update learning profile
      profile = @student.learning_profiles.find_or_create_by(subject: session.subject)
      update_proficiency(profile, accuracy, session)

      # Store in memory
      @memory_service.store_interaction(
        content: "Practice session on #{session.subject}: #{(accuracy * 100).round}% accuracy. Struggled with: #{session.struggled_topics.join(', ')}",
        topic: session.subject,
        source_type: 'practice',
        source_id: session.id
      )

      # Update goal progress if applicable
      update_goal_progress(session) if session.learning_goal

      {
        accuracy: accuracy,
        correct: session.correct_answers,
        total: session.total_problems,
        struggled_topics: session.struggled_topics.uniq,
        new_proficiency: profile.reload.proficiency_level
      }
    end

    private

    def determine_focus_topics(subject, profile)
      return [] unless profile

      # Prioritize weak areas and knowledge gaps
      gaps = @memory_service.identify_knowledge_gaps(subject)

      # Mix of weak areas and random topics for variety
      weak_topics = (profile.weaknesses || []) + (gaps[:struggled_topics] || [])
      weak_topics.uniq.sample(3)
    end

    def generate_problems(subject:, session_type:, num_problems:, difficulty:, focus_topics:, context:)
      context_text = context.map(&:content).join("\n\n")

      prompt = <<~PROMPT
        Generate #{num_problems} #{session_type} problems for #{subject}.

        Student's current difficulty level: #{difficulty}/10
        Focus topics (prioritize these): #{focus_topics.join(', ')}

        Recent learning context:
        #{context_text.truncate(2000)}

        Generate problems in JSON format:
        {
          "problems": [
            {
              "type": "#{session_type == 'flashcards' ? 'flashcard' : 'multiple_choice'}",
              "question": "The question text",
              "answer": "The correct answer",
              "options": ["A", "B", "C", "D"] // for multiple choice only
              "explanation": "Why this is the correct answer",
              "difficulty": #{difficulty},
              "topic": "specific topic"
            }
          ]
        }

        Guidelines:
        - Vary difficulty slightly around the target level (#{difficulty - 1} to #{difficulty + 1})
        - Make questions clear and unambiguous
        - For multiple choice, make distractors plausible but clearly wrong
        - Include helpful explanations
        - Cover the focus topics but include variety
      PROMPT

      response = @client.chat(
        parameters: {
          model: 'gpt-4-turbo-preview',
          messages: [{ role: 'user', content: prompt }],
          response_format: { type: 'json_object' },
          max_tokens: 4000
        }
      )

      result = JSON.parse(response.dig('choices', 0, 'message', 'content'))
      result['problems'].map(&:with_indifferent_access)
    end

    def check_answer(problem, student_answer)
      case problem.problem_type
      when 'multiple_choice'
        student_answer.to_s.strip.downcase == problem.correct_answer.to_s.strip.downcase
      when 'flashcard'
        # More lenient checking for flashcards
        similarity_check(student_answer, problem.correct_answer)
      else
        student_answer.to_s.strip.downcase == problem.correct_answer.to_s.strip.downcase
      end
    end

    def similarity_check(student_answer, correct_answer)
      # Normalize both answers
      student_normalized = student_answer.to_s.downcase.strip.gsub(/[^\w\s]/, '')
      correct_normalized = correct_answer.to_s.downcase.strip.gsub(/[^\w\s]/, '')

      # Exact match
      return true if student_normalized == correct_normalized

      # Check if student answer contains key parts of correct answer
      correct_words = correct_normalized.split.select { |w| w.length > 3 }
      student_words = student_normalized.split

      matching_words = correct_words.count { |w| student_words.any? { |sw| sw.include?(w) || w.include?(sw) } }
      matching_words.to_f / correct_words.length >= 0.7
    end

    def generate_feedback(problem, student_answer, is_correct)
      return "Correct! Great job!" if is_correct

      prompt = <<~PROMPT
        A student answered this question incorrectly:

        Question: #{problem.question}
        Correct Answer: #{problem.correct_answer}
        Student's Answer: #{student_answer}

        Provide a brief, encouraging feedback message (2-3 sentences) that:
        1. Acknowledges their attempt
        2. Explains why their answer was incorrect
        3. Points them toward the correct understanding
      PROMPT

      response = @client.chat(
        parameters: {
          model: 'gpt-4-turbo-preview',
          messages: [{ role: 'user', content: prompt }],
          max_tokens: 150
        }
      )

      response.dig('choices', 0, 'message', 'content')
    end

    def adjust_difficulty(session, is_correct)
      # Track recent performance
      recent_problems = session.practice_problems.order(created_at: :desc).limit(5)
      recent_accuracy = recent_problems.count(&:is_correct).to_f / recent_problems.length

      # Adjust for remaining problems
      remaining = session.practice_problems.where(student_answer: nil)

      if recent_accuracy >= 0.8
        # Increase difficulty
        remaining.update_all('difficulty_level = LEAST(difficulty_level + 1, 10)')
      elsif recent_accuracy <= 0.4
        # Decrease difficulty
        remaining.update_all('difficulty_level = GREATEST(difficulty_level - 1, 1)')
      end
    end

    def update_proficiency(profile, accuracy, session)
      current = profile.proficiency_level

      adjustment = if accuracy >= 0.9
        1
      elsif accuracy >= 0.7
        0.5
      elsif accuracy <= 0.4
        -0.5
      elsif accuracy <= 0.2
        -1
      else
        0
      end

      new_level = [[current + adjustment, 1].max, 10].min
      profile.update!(proficiency_level: new_level.round, last_assessed_at: Time.current)
    end

    def update_goal_progress(session)
      goal = session.learning_goal
      return unless goal

      # Calculate progress based on practice performance
      all_sessions = @student.practice_sessions.where(learning_goal: goal)
      avg_accuracy = all_sessions.average('correct_answers::float / NULLIF(total_problems, 0)') || 0

      # Progress is combination of sessions completed and accuracy
      sessions_factor = [all_sessions.count.to_f / 10, 0.5].min
      accuracy_factor = avg_accuracy * 0.5

      progress = ((sessions_factor + accuracy_factor) * 100).round

      goal.update!(progress_percentage: [progress, 100].min)
      goal.update!(status: :completed, completed_at: Time.current) if progress >= 100
    end

    def spaced_repetition_interval
      # Simple spaced repetition: review after 1, 3, 7, 14, 30 days
      7.days.ago
    end

    def regenerate_similar_problem(original_problem)
      prompt = <<~PROMPT
        Create a similar but different problem based on this one:

        Original Question: #{original_problem.question}
        Topic: #{original_problem.topic}
        Difficulty: #{original_problem.difficulty_level}
        Type: #{original_problem.problem_type}

        Generate a new problem that tests the same concept but with different numbers/wording.
        Return JSON: { "question": "...", "answer": "...", "options": [...], "explanation": "..." }
      PROMPT

      response = @client.chat(
        parameters: {
          model: 'gpt-4-turbo-preview',
          messages: [{ role: 'user', content: prompt }],
          response_format: { type: 'json_object' },
          max_tokens: 500
        }
      )

      JSON.parse(response.dig('choices', 0, 'message', 'content')).with_indifferent_access
    end
  end
end
```

### Practice Controller
Create `backend/app/controllers/api/v1/practice_sessions_controller.rb`:
```ruby
module Api
  module V1
    class PracticeSessionsController < ApplicationController
      before_action :set_session, only: [:show, :submit_answer, :complete]

      # GET /api/v1/practice_sessions
      def index
        sessions = current_student.practice_sessions
          .order(created_at: :desc)
          .limit(50)

        render json: sessions.map { |s| PracticeSessionSerializer.new(s) }
      end

      # POST /api/v1/practice_sessions
      def create
        service = AI::PracticeService.new(student: current_student)

        session = service.generate_session(
          subject: params[:subject],
          session_type: params[:session_type] || 'quiz',
          num_problems: params[:num_problems] || 10,
          goal: params[:goal_id] ? current_student.learning_goals.find(params[:goal_id]) : nil
        )

        render json: PracticeSessionSerializer.new(session, include_problems: true), status: :created
      end

      # GET /api/v1/practice_sessions/:id
      def show
        render json: PracticeSessionSerializer.new(@session, include_problems: true)
      end

      # POST /api/v1/practice_sessions/:id/submit
      def submit_answer
        service = AI::PracticeService.new(student: current_student)
        result = service.submit_answer(params[:problem_id], params[:answer])

        render json: result
      end

      # POST /api/v1/practice_sessions/:id/complete
      def complete
        service = AI::PracticeService.new(student: current_student)
        result = service.complete_session(@session.id)

        render json: result
      end

      # GET /api/v1/practice_sessions/review
      def review
        service = AI::PracticeService.new(student: current_student)
        problems = service.get_next_review_problems(
          subject: params[:subject],
          limit: params[:limit] || 5
        )

        render json: problems
      end

      private

      def set_session
        @session = current_student.practice_sessions.find(params[:id])
      end
    end
  end
end
```

### Practice Session Serializer
Create `backend/app/serializers/practice_session_serializer.rb`:
```ruby
class PracticeSessionSerializer
  def initialize(session, include_problems: false)
    @session = session
    @include_problems = include_problems
  end

  def as_json(*)
    data = {
      id: @session.id,
      subject: @session.subject,
      session_type: @session.session_type,
      total_problems: @session.total_problems,
      correct_answers: @session.correct_answers,
      accuracy: @session.total_problems > 0 ? (@session.correct_answers.to_f / @session.total_problems * 100).round(1) : 0,
      time_spent_seconds: @session.time_spent_seconds,
      struggled_topics: @session.struggled_topics,
      completed_at: @session.completed_at,
      created_at: @session.created_at
    }

    if @include_problems
      data[:problems] = @session.practice_problems.order(:created_at).map do |p|
        {
          id: p.id,
          type: p.problem_type,
          question: p.question,
          options: p.options,
          difficulty: p.difficulty_level,
          topic: p.topic,
          answered: p.student_answer.present?,
          is_correct: p.is_correct
        }
      end
    end

    data
  end
end
```

---

## Frontend Components

### Chat Hook
Create `frontend/src/hooks/useConversation.ts`:
```typescript
import { useState, useCallback, useRef, useEffect } from 'react';
import { api } from '../api/client';

interface Message {
  id: number;
  role: 'user' | 'assistant';
  content: string;
  created_at: string;
}

interface Conversation {
  id: number;
  subject: string | null;
  messages: Message[];
}

export function useConversation(conversationId?: number) {
  const [conversation, setConversation] = useState<Conversation | null>(null);
  const [messages, setMessages] = useState<Message[]>([]);
  const [isLoading, setIsLoading] = useState(false);
  const [isStreaming, setIsStreaming] = useState(false);
  const [streamingContent, setStreamingContent] = useState('');
  const wsRef = useRef<WebSocket | null>(null);

  // Load existing conversation
  useEffect(() => {
    if (conversationId) {
      loadConversation(conversationId);
    }
  }, [conversationId]);

  const loadConversation = async (id: number) => {
    const response = await api.get(`/api/v1/conversations/${id}`);
    setConversation(response.data);
    setMessages(response.data.messages || []);
  };

  const createConversation = async (initialMessage?: string, subject?: string) => {
    const response = await api.post('/api/v1/conversations', {
      initial_message: initialMessage,
      subject
    });
    setConversation(response.data);
    if (response.data.messages) {
      setMessages(response.data.messages);
    }
    return response.data;
  };

  const sendMessage = useCallback(async (content: string, useStreaming = true) => {
    if (!conversation) return;

    // Add user message immediately
    const userMessage: Message = {
      id: Date.now(),
      role: 'user',
      content,
      created_at: new Date().toISOString()
    };
    setMessages(prev => [...prev, userMessage]);

    if (useStreaming) {
      // Use WebSocket for streaming
      connectAndStream(content);
    } else {
      // Use REST API
      setIsLoading(true);
      try {
        const response = await api.post(`/api/v1/conversations/${conversation.id}/messages`, {
          content
        });
        setMessages(prev => [...prev, response.data]);
      } finally {
        setIsLoading(false);
      }
    }
  }, [conversation]);

  const connectAndStream = (content: string) => {
    const token = localStorage.getItem('token');
    const wsUrl = `${import.meta.env.VITE_WS_URL || 'ws://localhost:3000'}/cable?token=${token}`;

    const ws = new WebSocket(wsUrl);
    wsRef.current = ws;

    ws.onopen = () => {
      // Subscribe to conversation channel
      ws.send(JSON.stringify({
        command: 'subscribe',
        identifier: JSON.stringify({
          channel: 'ConversationChannel',
          conversation_id: conversation?.id
        })
      }));

      // Send message after subscription
      setTimeout(() => {
        ws.send(JSON.stringify({
          command: 'message',
          identifier: JSON.stringify({
            channel: 'ConversationChannel',
            conversation_id: conversation?.id
          }),
          data: JSON.stringify({ action: 'send_message', content })
        }));
        setIsStreaming(true);
        setStreamingContent('');
      }, 100);
    };

    ws.onmessage = (event) => {
      const data = JSON.parse(event.data);

      if (data.type === 'ping') return;

      if (data.message) {
        if (data.message.type === 'chunk') {
          setStreamingContent(prev => prev + data.message.content);
        } else if (data.message.type === 'complete') {
          // Add complete message
          setMessages(prev => [...prev, {
            id: Date.now(),
            role: 'assistant',
            content: streamingContent,
            created_at: new Date().toISOString()
          }]);
          setIsStreaming(false);
          setStreamingContent('');
          ws.close();
        }
      }
    };

    ws.onerror = () => {
      setIsStreaming(false);
      ws.close();
    };
  };

  return {
    conversation,
    messages,
    isLoading,
    isStreaming,
    streamingContent,
    createConversation,
    sendMessage,
    loadConversation
  };
}
```

### Practice Hook
Create `frontend/src/hooks/usePractice.ts`:
```typescript
import { useState, useCallback } from 'react';
import { api } from '../api/client';

interface Problem {
  id: number;
  type: string;
  question: string;
  options: string[];
  difficulty: number;
  topic: string;
  answered: boolean;
  is_correct: boolean | null;
}

interface PracticeSession {
  id: number;
  subject: string;
  session_type: string;
  total_problems: number;
  correct_answers: number;
  problems: Problem[];
}

interface SubmitResult {
  is_correct: boolean;
  correct_answer: string;
  explanation: string;
  feedback: string;
}

interface SessionResult {
  accuracy: number;
  correct: number;
  total: number;
  struggled_topics: string[];
  new_proficiency: number;
}

export function usePractice() {
  const [session, setSession] = useState<PracticeSession | null>(null);
  const [currentProblemIndex, setCurrentProblemIndex] = useState(0);
  const [isLoading, setIsLoading] = useState(false);
  const [lastResult, setLastResult] = useState<SubmitResult | null>(null);
  const [sessionResult, setSessionResult] = useState<SessionResult | null>(null);

  const startSession = useCallback(async (
    subject: string,
    sessionType: 'quiz' | 'flashcards' = 'quiz',
    numProblems = 10
  ) => {
    setIsLoading(true);
    try {
      const response = await api.post('/api/v1/practice_sessions', {
        subject,
        session_type: sessionType,
        num_problems: numProblems
      });
      setSession(response.data);
      setCurrentProblemIndex(0);
      setLastResult(null);
      setSessionResult(null);
      return response.data;
    } finally {
      setIsLoading(false);
    }
  }, []);

  const submitAnswer = useCallback(async (answer: string) => {
    if (!session) return;

    const problem = session.problems[currentProblemIndex];
    setIsLoading(true);

    try {
      const response = await api.post(`/api/v1/practice_sessions/${session.id}/submit`, {
        problem_id: problem.id,
        answer
      });

      setLastResult(response.data);

      // Update local state
      setSession(prev => {
        if (!prev) return prev;
        const updatedProblems = [...prev.problems];
        updatedProblems[currentProblemIndex] = {
          ...updatedProblems[currentProblemIndex],
          answered: true,
          is_correct: response.data.is_correct
        };
        return {
          ...prev,
          problems: updatedProblems,
          correct_answers: prev.correct_answers + (response.data.is_correct ? 1 : 0)
        };
      });

      return response.data;
    } finally {
      setIsLoading(false);
    }
  }, [session, currentProblemIndex]);

  const nextProblem = useCallback(() => {
    if (session && currentProblemIndex < session.problems.length - 1) {
      setCurrentProblemIndex(prev => prev + 1);
      setLastResult(null);
    }
  }, [session, currentProblemIndex]);

  const completeSession = useCallback(async () => {
    if (!session) return;

    setIsLoading(true);
    try {
      const response = await api.post(`/api/v1/practice_sessions/${session.id}/complete`);
      setSessionResult(response.data);
      return response.data;
    } finally {
      setIsLoading(false);
    }
  }, [session]);

  const currentProblem = session?.problems[currentProblemIndex] || null;
  const isComplete = session ? currentProblemIndex >= session.problems.length - 1 && lastResult !== null : false;

  return {
    session,
    currentProblem,
    currentProblemIndex,
    isLoading,
    lastResult,
    sessionResult,
    isComplete,
    startSession,
    submitAnswer,
    nextProblem,
    completeSession
  };
}
```

---

## Routes Update
Add to `backend/config/routes.rb`:
```ruby
namespace :api do
  namespace :v1 do
    # ... existing routes ...

    resources :conversations do
      member do
        post :messages, to: 'conversations#send_message'
      end
    end

    resources :practice_sessions do
      member do
        post :submit, to: 'practice_sessions#submit_answer'
        post :complete
      end
      collection do
        get :review
      end
    end
  end
end

# ActionCable mount
mount ActionCable.server => '/cable'
```

---

## Environment Variables Required

Add to `backend/.env`:
```
OPENAI_API_KEY=sk-your-openai-key
OPENAI_ORG_ID=org-optional
```

---

## Validation Checklist

After implementation, verify:
- [ ] `POST /api/v1/conversations` creates new conversation
- [ ] `POST /api/v1/conversations/:id/messages` returns AI response
- [ ] WebSocket streaming works via `/cable`
- [ ] Vector embeddings are stored in `knowledge_nodes`
- [ ] Semantic search returns relevant context
- [ ] `POST /api/v1/practice_sessions` generates problems
- [ ] Submit answer returns feedback and updates stats
- [ ] Complete session updates proficiency level
- [ ] Review endpoint returns spaced repetition problems

---

Execute this entire implementation. Create all files and ensure the AI conversation, memory, and practice systems work end-to-end.
