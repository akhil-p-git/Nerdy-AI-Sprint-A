class LearningProfileSerializer
  def initialize(profile, detailed: false)
    @profile = profile
    @detailed = detailed
  end

  def as_json(*)
    data = {
      id: @profile.id,
      subject: @profile.subject,
      proficiency_level: @profile.proficiency_level,
      strengths: @profile.strengths || [],
      weaknesses: @profile.weaknesses || [],
      last_assessed_at: @profile.last_assessed_at
    }

    if @detailed
      data[:knowledge_gaps] = @profile.knowledge_gaps || []
      data[:practice_stats] = practice_stats
      data[:session_count] = session_count
    end

    data
  end

  private

  def practice_stats
    sessions = @profile.student.practice_sessions.where(subject: @profile.subject)
    return {} if sessions.empty?

    {
      total_sessions: sessions.count,
      total_problems: sessions.sum(:total_problems),
      average_accuracy: calculate_accuracy(sessions)
    }
  end

  def calculate_accuracy(sessions)
    total = sessions.sum(:total_problems)
    return 0 if total.zero?
    ((sessions.sum(:correct_answers).to_f / total) * 100).round
  end

  def session_count
    @profile.student.tutoring_sessions.where(subject: @profile.subject).count
  end
end


