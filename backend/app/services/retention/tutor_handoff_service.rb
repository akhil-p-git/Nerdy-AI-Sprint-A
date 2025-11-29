module Retention
  class TutorHandoffService
    def initialize(conversation:)
      @conversation = conversation
      @student = conversation.student
      @detector = AI::EscalationDetector.new(conversation: conversation)
    end

    def check_and_suggest_handoff
      return nil unless @detector.should_escalate?

      context = @detector.generate_escalation_context

      # Create handoff suggestion
      suggestion = create_handoff_suggestion(context)

      # Notify student in conversation
      add_handoff_message(context)

      suggestion
    end

    def create_booking_with_context(tutor_id:, datetime:)
      context = @detector.generate_escalation_context

      # Get available tutors if not specified
      unless tutor_id
        tutors = find_suitable_tutors(context[:subject])
        tutor_id = tutors.first&.dig('id')
      end

      return nil unless tutor_id

      # Create booking via Nerdy platform
      client = Nerdy::PlatformClient.new
      booking = client.create_booking(
        student_id: @student.external_id,
        tutor_id: tutor_id,
        subject: context[:subject],
        datetime: datetime,
        notes: generate_tutor_notes(context)
      )

      if booking
        # Record the handoff
        TutorHandoff.create!(
          student: @student,
          conversation: @conversation,
          tutor_external_id: tutor_id,
          subject: context[:subject],
          escalation_reasons: context[:reasons],
          context_summary: context[:conversation_summary],
          focus_areas: context[:recommended_session_focus],
          booking_external_id: booking['id'],
          scheduled_at: datetime
        )
      end

      booking
    end

    private

    def create_handoff_suggestion(context)
      # Find available tutors
      tutors = find_suitable_tutors(context[:subject])

      # Find next available slots
      available_slots = find_available_slots(tutors)

      HandoffSuggestion.new(
        conversation: @conversation,
        context: context,
        available_tutors: tutors,
        available_slots: available_slots,
        urgency: context[:urgency]
      )
    end

    def add_handoff_message(context)
      urgency_message = case context[:urgency]
      when 'high'
        "I can see you're working hard on this, and I think a human tutor could really help you break through right now."
      when 'medium'
        "This is a great question that might benefit from working through with a tutor."
      else
        "Would you like to book a session with a tutor to dive deeper into this topic?"
      end

      message_content = <<~MSG
        #{urgency_message}

        **I can help you book a session** where you can:
        - Work through #{context[:recommended_session_focus].first(2).join(' and ')} in detail
        - Get personalized explanations and practice
        - Ask all your questions in real-time

        Would you like me to show you available tutors for #{context[:subject]}?
      MSG

      Message.create!(
        conversation: @conversation,
        role: 'assistant',
        content: message_content,
        metadata: {
          type: 'handoff_suggestion',
          context: context
        }
      )
    end

    def find_suitable_tutors(subject)
      client = Nerdy::PlatformClient.new
      client.get_available_tutors(
        subject: subject,
        datetime: Time.current,
        duration: 60
      )
    end

    def find_available_slots(tutors)
      # Aggregate available slots from tutors
      tutors.flat_map do |tutor|
        (tutor['available_slots'] || []).map do |slot|
          {
            tutor_id: tutor['id'],
            tutor_name: "#{tutor['first_name']} #{tutor['last_name']}",
            datetime: slot['datetime'],
            duration: slot['duration']
          }
        end
      end.sort_by { |s| s[:datetime] }.first(10)
    end

    def generate_tutor_notes(context)
      <<~NOTES
        **AI Companion Handoff Notes**

        Student has been working with AI companion on: #{context[:subject]}

        **Summary:** #{context[:conversation_summary]}

        **Recommended Focus Areas:**
        #{context[:recommended_session_focus].map { |a| "- #{a}" }.join("\n")}

        **Escalation Reason:** #{context[:reasons].join(', ')}

        **Urgency:** #{context[:urgency]}
      NOTES
    end
  end

  class HandoffSuggestion
    attr_reader :conversation, :context, :available_tutors, :available_slots, :urgency

    def initialize(conversation:, context:, available_tutors:, available_slots:, urgency:)
      @conversation = conversation
      @context = context
      @available_tutors = available_tutors
      @available_slots = available_slots
      @urgency = urgency
    end

    def to_h
      {
        subject: context[:subject],
        reasons: context[:reasons],
        summary: context[:conversation_summary],
        focus_areas: context[:recommended_session_focus],
        urgency: urgency,
        available_tutors: available_tutors.first(5),
        available_slots: available_slots.first(5)
      }
    end
  end
end


