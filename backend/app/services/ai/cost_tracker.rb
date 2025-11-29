module AI
  class CostTracker
    COSTS = {
      'gpt-4-turbo-preview' => { input: 0.01, output: 0.03 },  # per 1K tokens
      'gpt-4' => { input: 0.03, output: 0.06 },
      'gpt-3.5-turbo' => { input: 0.0005, output: 0.0015 },
      'text-embedding-3-small' => { input: 0.00002, output: 0 }
    }.freeze

    class << self
      def track(model:, input_tokens:, output_tokens:, student_id: nil, operation: nil)
        cost = calculate_cost(model, input_tokens, output_tokens)

        AIUsageLog.create!(
          student_id: student_id,
          model: model,
          operation: operation,
          input_tokens: input_tokens,
          output_tokens: output_tokens,
          cost_usd: cost,
          created_at: Time.current
        )

        # Update daily/monthly aggregates
        update_aggregates(student_id, cost)

        cost
      end

      def daily_cost(date: Date.current)
        AIUsageLog.where('DATE(created_at) = ?', date).sum(:cost_usd)
      end

      def monthly_cost(month: Date.current.beginning_of_month)
        AIUsageLog.where('created_at >= ?', month).sum(:cost_usd)
      end

      def student_cost(student_id, period: 30.days)
        AIUsageLog.where(student_id: student_id)
          .where('created_at > ?', period.ago)
          .sum(:cost_usd)
      end

      private

      def calculate_cost(model, input_tokens, output_tokens)
        rates = COSTS[model] || COSTS['gpt-4-turbo-preview']
        input_cost = (input_tokens / 1000.0) * rates[:input]
        output_cost = (output_tokens / 1000.0) * rates[:output]
        (input_cost + output_cost).round(6)
      end

      def update_aggregates(student_id, cost)
        # Update daily aggregate
        key = "ai_cost:daily:#{Date.current}"
        REDIS.incrbyfloat(key, cost)
        REDIS.expire(key, 7.days.to_i)

        # Update student aggregate if applicable
        if student_id
          student_key = "ai_cost:student:#{student_id}:#{Date.current.beginning_of_month.strftime('%Y%m')}"
          REDIS.incrbyfloat(student_key, cost)
          REDIS.expire(student_key, 60.days.to_i)
        end
      end
    end
  end
end


