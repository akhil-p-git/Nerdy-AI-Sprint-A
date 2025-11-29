class TutorBriefSerializer
  def initialize(brief, full: false)
    @brief = brief
    @full = full
  end

  def as_json(*)
    data = {
      id: @brief.id,
      student_name: "#{@brief.student.first_name} #{@brief.student.last_name}",
      subject: @brief.subject,
      session_datetime: @brief.session_datetime,
      viewed: @brief.viewed,
      created_at: @brief.created_at
    }

    if @full
      data.merge!({
        content: @brief.content,
        data_snapshot: @brief.data_snapshot,
        viewed_at: @brief.viewed_at
      })
    end

    data
  end
end


