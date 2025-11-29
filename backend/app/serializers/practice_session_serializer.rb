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

