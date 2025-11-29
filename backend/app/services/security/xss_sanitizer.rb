module Security
  class XssSanitizer
    SCRIPT_PATTERNS = [
      /<script\b[^>]*>.*?<\/script>/mi,
      /javascript:/i,
      /on\w+\s*=/i,
      /data:/i
    ].freeze

    class << self
      def sanitize(input)
        return nil if input.nil?
        return input unless input.is_a?(String)

        result = input.dup

        # Remove script tags and event handlers
        SCRIPT_PATTERNS.each do |pattern|
          result.gsub!(pattern, '')
        end

        # Encode HTML entities
        CGI.escapeHTML(result)
      end

      def sanitize_hash(hash)
        hash.transform_values do |value|
          case value
          when String then sanitize(value)
          when Hash then sanitize_hash(value)
          when Array then value.map { |v| v.is_a?(String) ? sanitize(v) : v }
          else value
          end
        end
      end
    end
  end
end


