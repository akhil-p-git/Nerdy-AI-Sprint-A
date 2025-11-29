module AI
  class TutorBriefService
    def initialize(student:, tutor:, subject:, session_datetime:)
      @student = student
      @tutor = tutor
      @subject = subject
      @session_datetime = session_datetime
      @memory_service = MemoryService.new(student: student)
    end

    def generate_brief
      # Gather all relevant data
      data = gather_student_data

      # Generate AI summary
      brief = generate_ai_brief(data)

      # Store the brief
      TutorBrief.create!(
        student: @student,
        tutor: @tutor,
        subject: @subject,
        session_datetime: @session_datetime,
        content: brief,
        data_snapshot: data
      )

      brief
    end

    private

    def gather_student_data
      {
        student_info: student_info,
        learning_profile: learning_profile_data,
        recent_sessions: recent_sessions_data,
        ai_interactions: ai_interactions_data,
        practice_performance: practice_performance_data,
        active_goals: active_goals_data,
        knowledge_gaps: knowledge_gaps_data,
        handoff_context: handoff_context_data
      }
    end

    def student_info
      {
        name: "#{@student.first_name} #{@student.last_name}",
        learning_style: @student.learning_style,
        preferences: @student.preferences
      }
    end

    def learning_profile_data
      profile = @student.learning_profiles.find_by(subject: @subject)
      return {} unless profile

      {
        proficiency_level: profile.proficiency_level,
        strengths: profile.strengths || [],
        weaknesses: profile.weaknesses || [],
        knowledge_gaps: profile.knowledge_gaps || []
      }
    end

    def recent_sessions_data
      sessions = @student.tutoring_sessions
        .where(subject: @subject)
        .order(created_at: :desc)
        .limit(3)

      sessions.map do |s|
        {
          date: s.started_at&.strftime('%B %d'),
          tutor: s.tutor&.first_name,
          summary: s.summary,
          topics: s.topics_covered,
          key_concepts: s.key_concepts
        }
      end
    end

    def ai_interactions_data
      conversations = @student.conversations
        .where(subject: @subject)
        .where('updated_at > ?', 14.days.ago)
        .order(updated_at: :desc)
        .limit(3)

      conversations.map do |c|
        messages = c.messages.order(created_at: :desc).limit(10).reverse

        {
          date: c.updated_at.strftime('%B %d'),
          message_count: c.messages.count,
          sample_questions: messages.select { |m| m.role == 'user' }.map { |m| m.content.truncate(100) }
        }
      end
    end

    def practice_performance_data
      practices = @student.practice_sessions
        .where(subject: @subject)
        .where('created_at > ?', 30.days.ago)

      return {} if practices.empty?

      {
        total_sessions: practices.count,
        average_accuracy: (practices.average('correct_answers::float / NULLIF(total_problems, 0)') * 100).round,
        total_problems: practices.sum(:total_problems),
        struggled_topics: practices.flat_map(&:struggled_topics).tally.sort_by { |_, v| -v }.first(5).map(&:first)
      }
    end

    def active_goals_data
      goals = @student.learning_goals
        .where(subject: @subject)
        .where(status: [:active, :pending])

      goals.map do |g|
        {
          title: g.title,
          progress: g.progress_percentage,
          target_date: g.target_date,
          milestones: g.milestones
        }
      end
    end

    def knowledge_gaps_data
      @memory_service.identify_knowledge_gaps(@subject)
    end

    def handoff_context_data
      handoff = TutorHandoff
        .where(student: @student, tutor_external_id: @tutor.external_id)
        .where('scheduled_at > ?', 1.day.ago)
        .order(created_at: :desc)
        .first

      return {} unless handoff

      {
        escalation_reasons: handoff.escalation_reasons,
        context_summary: handoff.context_summary,
        focus_areas: handoff.focus_areas
      }
    end

    def generate_ai_brief(data)
      client = OpenAI::Client.new

      prompt = <<~PROMPT
        Generate a tutor preparation brief for an upcoming session.

        **Student:** #{data[:student_info][:name]}
        **Subject:** #{@subject}
        **Session Date:** #{@session_datetime.strftime('%B %d, %Y at %I:%M %p')}

        **Learning Profile:**
        - Proficiency Level: #{data[:learning_profile][:proficiency_level]}/10
        - Strengths: #{data[:learning_profile][:strengths]&.join(', ') || 'Not yet assessed'}
        - Weaknesses: #{data[:learning_profile][:weaknesses]&.join(', ') || 'Not yet assessed'}

        **Recent Tutoring Sessions:**
        #{data[:recent_sessions].map { |s| "- #{s[:date]}: #{s[:summary]}" }.join("\n")}

        **AI Companion Interactions (last 2 weeks):**
        #{data[:ai_interactions].map { |i| "- #{i[:date]}: #{i[:message_count]} messages. Questions: #{i[:sample_questions].join('; ')}" }.join("\n")}

        **Practice Performance:**
        - Sessions: #{data[:practice_performance][:total_sessions] || 0}
        - Accuracy: #{data[:practice_performance][:average_accuracy] || 'N/A'}%
        - Struggled Topics: #{data[:practice_performance][:struggled_topics]&.join(', ') || 'None identified'}

        **Active Goals:**
        #{data[:active_goals].map { |g| "- #{g[:title]} (#{g[:progress]}% complete)" }.join("\n")}

        **Knowledge Gaps:**
        #{data[:knowledge_gaps][:struggled_topics]&.join(', ') || 'None identified'}

        #{data[:handoff_context].present? ? "**AI Handoff Context:**\n#{data[:handoff_context][:context_summary]}\nFocus Areas: #{data[:handoff_context][:focus_areas]&.join(', ')}" : ''}

        ---

        Generate a brief (300-400 words) that includes:

        1. **Quick Summary** (2-3 sentences): Who this student is and where they are in their learning journey.

        2. **Session Focus Recommendations**: Top 3 things to prioritize in this session.

        3. **Watch Out For**: Any patterns of confusion or frustration to be aware of.

        4. **Suggested Approach**: Teaching strategies that might work well based on their history.

        5. **Conversation Starters**: 2-3 questions to build rapport and assess understanding.

        Format with clear headers and bullet points for easy scanning.
      PROMPT

      response = client.chat(
        parameters: {
          model: 'gpt-4-turbo-preview',
          messages: [{ role: 'user', content: prompt }],
          max_tokens: 800
        }
      )

      response.dig('choices', 0, 'message', 'content')
    end
  end
end


