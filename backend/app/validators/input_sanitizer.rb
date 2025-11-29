class InputSanitizer
  class << self
    def sanitize_string(input)
      return nil if input.nil?

      input.to_s
        .strip
        .gsub(/[\x00-\x08\x0B\x0C\x0E-\x1F]/, '') # Remove control characters
    end

    def sanitize_html(input)
      return nil if input.nil?

      ActionController::Base.helpers.sanitize(
        input.to_s,
        tags: %w[p br strong em ul ol li a code pre],
        attributes: %w[href class]
      )
    end

    def sanitize_email(input)
      return nil if input.nil?

      email = input.to_s.strip.downcase
      return nil unless email.match?(URI::MailTo::EMAIL_REGEXP)

      email
    end

    def sanitize_integer(input, min: nil, max: nil)
      value = input.to_i
      value = [value, min].max if min
      value = [value, max].min if max
      value
    end

    def sanitize_array(input, allowed_values: nil)
      return [] unless input.is_a?(Array)

      result = input.map { |i| sanitize_string(i) }.compact
      result = result.select { |i| allowed_values.include?(i) } if allowed_values
      result
    end
  end
end


