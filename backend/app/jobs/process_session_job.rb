class ProcessSessionJob < ApplicationJob
  queue_as :default
  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  def perform(session_id)
    session = TutoringSession.find(session_id)
    return if session.summary.present? # Already processed

    # Fetch transcript
    client = Nerdy::PlatformClient.new
    transcript = client.get_transcript(session.external_session_id)

    return unless transcript.present?

    # Analyze with AI
    analysis = analyze_transcript(transcript, session.subject)

    # Update session
    session.update!(
      summary: analysis[:summary],
      topics_covered: analysis[:topics],
      key_concepts: analysis[:concepts]
    )

    # Store in vector memory
    store_in_memory(session, analysis)

    # Update learning profile
    update_learning_profile(session, analysis)

    # Check for goal progress
    check_goal_progress(session, analysis)
  end

  private

  def analyze_transcript(transcript, subject)
    client = OpenAI::Client.new

    prompt = <<~PROMPT
      Analyze this #{subject} tutoring session transcript:

      #{transcript.truncate(12000)}

      Provide JSON response:
      {
        "summary": "2-3 sentence summary",
        "topics": ["topic1", "topic2"],
        "concepts": ["concept1", "concept2"],
        "student_struggles": ["area1", "area2"],
        "mastery_demonstrated": ["concept1"],
        "recommended_practice": ["topic to practice"],
        "follow_up_topics": ["next topic to cover"],
        "engagement_level": "high|medium|low",
        "comprehension_score": 1-10
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

  def store_in_memory(session, analysis)
    memory_service = AI::MemoryService.new(student: session.student)

    content = <<~TEXT
      Tutoring session on #{session.subject} with #{session.tutor&.first_name || 'tutor'}
      Date: #{session.started_at&.strftime('%B %d, %Y')}

      Summary: #{analysis[:summary]}

      Topics covered: #{analysis[:topics].join(', ')}
      Key concepts: #{analysis[:concepts].join(', ')}
      Areas of struggle: #{analysis[:student_struggles].join(', ')}
      Demonstrated mastery: #{analysis[:mastery_demonstrated].join(', ')}
    TEXT

    memory_service.store_interaction(
      content: content,
      topic: session.subject,
      source_type: 'session',
      source_id: session.id,
      metadata: {
        tutor_id: session.tutor_id,
        comprehension_score: analysis[:comprehension_score],
        engagement_level: analysis[:engagement_level]
      }
    )
  end

  def update_learning_profile(session, analysis)
    profile = session.student.learning_profiles.find_or_create_by(subject: session.subject)

    # Update strengths (mastery demonstrated)
    current_strengths = profile.strengths || []
    new_strengths = (current_strengths + (analysis[:mastery_demonstrated] || [])).uniq.last(20)

    # Update weaknesses (struggles)
    current_weaknesses = profile.weaknesses || []
    # Remove weaknesses that are now mastered
    updated_weaknesses = current_weaknesses - (analysis[:mastery_demonstrated] || [])
    # Add new struggles
    updated_weaknesses = (updated_weaknesses + (analysis[:student_struggles] || [])).uniq.last(20)

    profile.update!(
      strengths: new_strengths,
      weaknesses: updated_weaknesses,
      last_assessed_at: Time.current
    )
  end

  def check_goal_progress(session, analysis)
    # Find active goals for this subject
    goals = session.student.learning_goals
      .where(subject: session.subject, status: :active)

    goals.each do |goal|
      Retention::GoalProgressService.new(goal: goal).check_and_update(
        session: session,
        analysis: analysis
      )
    end
  end
end
