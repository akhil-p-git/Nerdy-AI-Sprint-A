class StudentSerializer
  def initialize(student)
    @student = student
  end

  def as_json(options = {})
    {
      id: @student.id,
      external_id: @student.external_id,
      email: @student.email,
      first_name: @student.first_name,
      last_name: @student.last_name,
      preferences: @student.preferences,
      learning_style: @student.learning_style
    }
  end
end

