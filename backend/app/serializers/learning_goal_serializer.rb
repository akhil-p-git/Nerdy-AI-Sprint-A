class LearningGoalSerializer
  def initialize(goal, detailed: false)
    @goal = goal
    @detailed = detailed
  end

  def as_json(*)
    data = {
      id: @goal.id,
      subject: @goal.subject,
      title: @goal.title,
      description: @goal.description,
      status: @goal.status,
      progress_percentage: @goal.progress_percentage,
      target_date: @goal.target_date,
      milestones: @goal.milestones || [],
      created_at: @goal.created_at,
      completed_at: @goal.completed_at
    }

    if @detailed
      data[:suggested_next_goals] = @goal.suggested_next_goals || []
      data[:target_outcome] = @goal.target_outcome
      data[:related_practice_sessions] = related_practice_count
      data[:related_tutoring_sessions] = related_tutoring_count
    end

    data
  end

  private

  def related_practice_count
    @goal.student.practice_sessions
      .where(subject: @goal.subject)
      .where('created_at >= ?', @goal.created_at)
      .count
  end

  def related_tutoring_count
    @goal.student.tutoring_sessions
      .where(subject: @goal.subject)
      .where('created_at >= ?', @goal.created_at)
      .count
  end
end


