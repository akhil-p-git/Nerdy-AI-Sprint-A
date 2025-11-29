module AI
  class CacheService
    CACHE_TTL = {
      embedding: 7.days,
      practice_problem: 24.hours,
      subject_context: 1.hour,
      conversation_context: 30.minutes
    }.freeze

    class << self
      # Cache embeddings to avoid regenerating
      def cache_embedding(text, &block)
        key = embedding_key(text)
        cached = Rails.cache.read(key)
        return cached if cached

        result = block.call
        Rails.cache.write(key, result, expires_in: CACHE_TTL[:embedding])
        result
      end

      # Cache practice problems by topic/difficulty
      def cache_practice_problems(subject:, topic:, difficulty:, &block)
        key = practice_key(subject, topic, difficulty)
        cached = Rails.cache.read(key)

        if cached && cached.length >= 5
          # Return subset of cached problems
          return cached.sample(5)
        end

        result = block.call
        existing = cached || []
        Rails.cache.write(key, (existing + result).uniq { |p| p[:question] }.last(50), expires_in: CACHE_TTL[:practice_problem])
        result
      end

      # Cache subject context for a student
      def cache_subject_context(student_id:, subject:, &block)
        key = subject_context_key(student_id, subject)
        Rails.cache.fetch(key, expires_in: CACHE_TTL[:subject_context], &block)
      end

      # Cache conversation context
      def cache_conversation_context(conversation_id:, &block)
        key = conversation_context_key(conversation_id)
        Rails.cache.fetch(key, expires_in: CACHE_TTL[:conversation_context], &block)
      end

      # Invalidate caches when data changes
      def invalidate_student_cache(student_id)
        pattern = "student:#{student_id}:*"
        keys = Rails.cache.redis.keys(pattern)
        Rails.cache.delete_multi(keys) if keys.any?
      end

      def invalidate_conversation_cache(conversation_id)
        Rails.cache.delete(conversation_context_key(conversation_id))
      end

      private

      def embedding_key(text)
        hash = Digest::SHA256.hexdigest(text.to_s.downcase.strip)
        "embedding:#{hash}"
      end

      def practice_key(subject, topic, difficulty)
        "practice:#{subject}:#{topic}:#{difficulty}"
      end

      def subject_context_key(student_id, subject)
        "student:#{student_id}:context:#{subject}"
      end

      def conversation_context_key(conversation_id)
        "conversation:#{conversation_id}:context"
      end
    end
  end
end


