module Compliance
  class CoppaService
    MIN_AGE_WITHOUT_CONSENT = 13

    class << self
      def requires_parental_consent?(birth_date)
        return true if birth_date.nil?

        age = calculate_age(birth_date)
        age < MIN_AGE_WITHOUT_CONSENT
      end

      def can_collect_data?(student)
        return true unless requires_parental_consent?(student.birth_date)

        # Check for parental consent
        # Placeholder for ParentalConsent model which would track consent status
        # ParentalConsent.exists?(
        #   student: student,
        #   status: 'approved',
        #   expires_at: Time.current..
        # )
        false # Default to false if under 13 and no consent system implemented yet
      end

      def sensitive_data_fields
        %w[
          email
          phone_number
          address
          birth_date
          school_name
          parent_email
        ]
      end

      def anonymize_student_data(student)
        # Replace PII with anonymized values
        student.update!(
          email: "anonymized_#{student.id}@example.com",
          first_name: 'Anonymized',
          last_name: 'User',
          preferences: {},
          learning_style: {}
        )

        # Remove from related data
        student.conversations.destroy_all
        student.knowledge_nodes.destroy_all

        Rails.logger.info("Student #{student.id} data anonymized for COPPA compliance")
      end

      private

      def calculate_age(birth_date)
        today = Date.current
        age = today.year - birth_date.year
        age -= 1 if today < birth_date + age.years
        age
      end
    end
  end
end


