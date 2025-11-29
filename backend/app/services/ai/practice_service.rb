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

