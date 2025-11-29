module Api
  module V1
    module Admin
      class AnalyticsController < ApplicationController
        skip_before_action :authenticate_request
        before_action :authenticate_admin

        # GET /api/v1/admin/analytics/overview
        def overview
          render json: {
            daily_active_users: Analytics::MetricsService.daily_active_users,
            weekly_retention: Analytics::MetricsService.weekly_retention(cohort_start: 7.days.ago.to_date),
            conversion_funnel: Analytics::MetricsService.conversion_funnel,
            ai_costs: {
              today: AI::CostTracker.daily_cost,
              this_month: AI::CostTracker.monthly_cost
            }
          }
        end

        # GET /api/v1/admin/analytics/engagement
        def engagement
          period = params[:period]&.to_i&.days || 30.days

          render json: {
            conversations_started: count_events('conversation_started', period),
            messages_sent: count_events('message_sent', period),
            practice_sessions: count_events('practice_completed', period),
            goals_completed: count_events('goal_completed', period),
            tutor_handoffs: count_events('tutor_handoff', period),
            nudges_sent: count_events('nudge_sent', period),
            nudges_acted: count_events('nudge_acted', period)
          }
        end

        # GET /api/v1/admin/analytics/learning
        def learning
          render json: {
            average_accuracy: average_metric('practice_completed', 'accuracy'),
            average_time_per_session: average_metric('practice_completed', 'time_spent'),
            most_practiced_subjects: top_subjects,
            common_struggle_topics: common_struggles
          }
        end

        private

        def authenticate_admin
          # Implement admin authentication
          token = request.headers['X-Admin-Token']
          render json: { error: 'Unauthorized' }, status: :unauthorized unless token == ENV['ADMIN_TOKEN']
        end

        def count_events(event_name, period)
          AnalyticsEvent.where(event_name: event_name)
            .where('occurred_at > ?', period.ago)
            .count
        end

        def average_metric(event_name, metric)
          events = AnalyticsEvent.where(event_name: event_name)
            .where('occurred_at > ?', 30.days.ago)

          values = events.pluck(:properties).map { |p| p[metric] }.compact
          return 0 if values.empty?

          (values.sum.to_f / values.length).round(1)
        end

        def top_subjects
          AnalyticsEvent.where(event_name: 'practice_completed')
            .where('occurred_at > ?', 30.days.ago)
            .pluck(:properties)
            .map { |p| p['subject'] }
            .tally
            .sort_by { |_, v| -v }
            .first(10)
            .to_h
        end

        def common_struggles
          AnalyticsEvent.where(event_name: 'practice_completed')
            .where('occurred_at > ?', 30.days.ago)
            .pluck(:properties)
            .flat_map { |p| p['struggled_topics'] || [] }
            .tally
            .sort_by { |_, v| -v }
            .first(10)
            .to_h
        end
      end
    end
  end
end


