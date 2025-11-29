module Security
  class QuerySanitizer
    DANGEROUS_PATTERNS = [
      /;\s*drop\s+/i,
      /;\s*delete\s+/i,
      /;\s*update\s+/i,
      /;\s*insert\s+/i,
      /union\s+select/i,
      /--/,
      /\/\*/
    ].freeze

    class << self
      def safe?(input)
        return true if input.nil?

        str = input.to_s
        DANGEROUS_PATTERNS.none? { |pattern| str.match?(pattern) }
      end

      def sanitize_for_like(input)
        return '' if input.nil?

        input.to_s.gsub(/[%_\\]/) { |c| "\\#{c}" }
      end

      def validate_sort_column(column, allowed_columns)
        return allowed_columns.first unless allowed_columns.include?(column.to_s)

        column.to_s
      end

      def validate_sort_direction(direction)
        %w[asc desc].include?(direction.to_s.downcase) ? direction.to_s.downcase : 'asc'
      end
    end
  end
end


