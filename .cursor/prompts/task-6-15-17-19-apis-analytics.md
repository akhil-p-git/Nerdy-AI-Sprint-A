# One-Shot Prompt: APIs, Parent Dashboard, Caching & Analytics (Tasks 6, 15, 17, 19)

## Context
Building supporting backend APIs, the parent dashboard, performance optimizations, and analytics tracking for the Nerdy AI Study Companion.

## Your Mission
- **Task 6:** Student Learning Profile API
- **Task 15:** Parent Dashboard View
- **Task 17:** API Rate Limiting and Caching
- **Task 19:** Analytics and Metrics Collection

---

## Task 6: Student Learning Profile API

### Learning Profile Controller
Create `backend/app/controllers/api/v1/learning_profiles_controller.rb`:
```ruby
module Api
  module V1
    class LearningProfilesController < ApplicationController
      before_action :set_profile, only: [:show, :update]

      # GET /api/v1/learning_profiles
      def index
        profiles = current_student.learning_profiles.order(:subject)
        render json: profiles.map { |p| LearningProfileSerializer.new(p) }
      end

      # GET /api/v1/learning_profiles/:id
      def show
        render json: LearningProfileSerializer.new(@profile, detailed: true)
      end

      # PUT /api/v1/learning_profiles/:id
      def update
        if @profile.update(profile_params)
          render json: LearningProfileSerializer.new(@profile)
        else
          render json: { errors: @profile.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # GET /api/v1/learning_profiles/summary
      def summary
        profiles = current_student.learning_profiles

        summary = {
          total_subjects: profiles.count,
          average_proficiency: profiles.average(:proficiency_level)&.round(1) || 0,
          strongest_subject: profiles.order(proficiency_level: :desc).first&.subject,
          weakest_subject: profiles.order(proficiency_level: :asc).first&.subject,
          subjects: profiles.map do |p|
            {
              subject: p.subject,
              proficiency: p.proficiency_level,
              strengths_count: p.strengths&.length || 0,
              weaknesses_count: p.weaknesses&.length || 0
            }
          end
        }

        render json: summary
      end

      private

      def set_profile
        @profile = current_student.learning_profiles.find(params[:id])
      end

      def profile_params
        params.permit(:proficiency_level, strengths: [], weaknesses: [], knowledge_gaps: [])
      end
    end
  end
end
```

### Learning Goals Controller
Create `backend/app/controllers/api/v1/learning_goals_controller.rb`:
```ruby
module Api
  module V1
    class LearningGoalsController < ApplicationController
      before_action :set_goal, only: [:show, :update, :destroy, :suggestions, :evaluate_completion]

      # GET /api/v1/learning_goals
      def index
        goals = current_student.learning_goals

        # Filter by status
        goals = goals.where(status: params[:status]) if params[:status].present?

        # Filter by subject
        goals = goals.where(subject: params[:subject]) if params[:subject].present?

        goals = goals.order(created_at: :desc)

        render json: goals.map { |g| LearningGoalSerializer.new(g) }
      end

      # GET /api/v1/learning_goals/:id
      def show
        render json: LearningGoalSerializer.new(@goal, detailed: true)
      end

      # POST /api/v1/learning_goals
      def create
        goal = current_student.learning_goals.build(goal_params)
        goal.status = :active

        if goal.save
          render json: LearningGoalSerializer.new(goal), status: :created
        else
          render json: { errors: goal.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # PUT /api/v1/learning_goals/:id
      def update
        if @goal.update(goal_params)
          render json: LearningGoalSerializer.new(@goal)
        else
          render json: { errors: @goal.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/learning_goals/:id
      def destroy
        @goal.destroy
        head :no_content
      end

      # GET /api/v1/learning_goals/:id/suggestions
      def suggestions
        recommendations = Retention::SubjectRecommendations.get_recommendations(@goal.subject)

        render json: {
          completed_goal: @goal.title,
          message: recommendations[:message],
          suggestions: recommendations[:next_subjects].map do |subject|
            {
              subject: subject,
              reason: "Based on your progress in #{@goal.subject}",
              priority: recommendations[:priority_order].index(subject) || 99
            }
          end.sort_by { |s| s[:priority] }
        }
      end

      # POST /api/v1/learning_goals/:id/evaluate_completion
      def evaluate_completion
        service = Retention::GoalProgressService.new(goal: @goal)
        evaluation = service.evaluate_completion

        render json: evaluation
      end

      # POST /api/v1/learning_goals/:id/milestones
      def add_milestone
        @goal = current_student.learning_goals.find(params[:id])
        milestones = @goal.milestones || []

        milestones << {
          id: SecureRandom.uuid,
          title: params[:title],
          completed: false,
          created_at: Time.current
        }

        @goal.update!(milestones: milestones)
        render json: LearningGoalSerializer.new(@goal)
      end

      # PUT /api/v1/learning_goals/:id/milestones/:milestone_id
      def update_milestone
        @goal = current_student.learning_goals.find(params[:id])
        milestones = @goal.milestones || []

        milestone = milestones.find { |m| m['id'] == params[:milestone_id] }
        if milestone
          milestone['completed'] = params[:completed]
          milestone['completed_at'] = Time.current if params[:completed]
          @goal.update!(milestones: milestones)

          # Recalculate progress
          completed_count = milestones.count { |m| m['completed'] }
          progress = (completed_count.to_f / milestones.length * 100).round
          @goal.update!(progress_percentage: progress)
        end

        render json: LearningGoalSerializer.new(@goal)
      end

      private

      def set_goal
        @goal = current_student.learning_goals.find(params[:id])
      end

      def goal_params
        params.permit(:subject, :title, :description, :target_outcome, :target_date, :status, :progress_percentage)
      end
    end
  end
end
```

### Stats Controller
Create `backend/app/controllers/api/v1/stats_controller.rb`:
```ruby
module Api
  module V1
    class StatsController < ApplicationController
      # GET /api/v1/stats
      def index
        stats = {
          total_sessions: current_student.tutoring_sessions.count,
          total_practice_problems: total_practice_problems,
          average_accuracy: average_accuracy,
          current_streak: calculate_streak,
          goals_completed: current_student.learning_goals.where(status: :completed).count,
          active_goals: current_student.learning_goals.where(status: :active).count,
          total_conversation_messages: total_messages,
          time_spent_minutes: calculate_time_spent
        }

        render json: stats
      end

      # GET /api/v1/stats/weekly
      def weekly
        weeks = 8
        data = (0...weeks).map do |i|
          week_start = i.weeks.ago.beginning_of_week
          week_end = i.weeks.ago.end_of_week

          {
            week: week_start.strftime('%b %d'),
            sessions: current_student.tutoring_sessions.where(created_at: week_start..week_end).count,
            practice_problems: current_student.practice_sessions.where(created_at: week_start..week_end).sum(:total_problems),
            accuracy: weekly_accuracy(week_start, week_end)
          }
        end.reverse

        render json: data
      end

      private

      def total_practice_problems
        current_student.practice_sessions.sum(:total_problems)
      end

      def average_accuracy
        sessions = current_student.practice_sessions.where('total_problems > 0')
        return 0 if sessions.empty?

        total_correct = sessions.sum(:correct_answers)
        total_problems = sessions.sum(:total_problems)
        ((total_correct.to_f / total_problems) * 100).round
      end

      def calculate_streak
        dates = current_student.practice_sessions
          .or(current_student.conversations.where('updated_at > created_at'))
          .pluck(:created_at)
          .map(&:to_date)
          .uniq
          .sort
          .reverse

        return 0 if dates.empty?

        streak = 0
        current_date = Date.current

        dates.each do |date|
          if date == current_date || date == current_date - streak.days
            streak += 1
            current_date = date
          else
            break
          end
        end

        streak
      end

      def total_messages
        Message.joins(:conversation)
          .where(conversations: { student_id: current_student.id })
          .count
      end

      def calculate_time_spent
        # Estimate based on sessions and practice
        session_minutes = current_student.tutoring_sessions.sum do |s|
          next 0 unless s.started_at && s.ended_at
          ((s.ended_at - s.started_at) / 60).round
        end

        practice_minutes = current_student.practice_sessions.sum(:time_spent_seconds) / 60

        session_minutes + practice_minutes
      end

      def weekly_accuracy(week_start, week_end)
        sessions = current_student.practice_sessions
          .where(created_at: week_start..week_end)
          .where('total_problems > 0')

        return 0 if sessions.empty?

        total_correct = sessions.sum(:correct_answers)
        total_problems = sessions.sum(:total_problems)
        ((total_correct.to_f / total_problems) * 100).round
      end
    end
  end
end
```

### Activities Controller
Create `backend/app/controllers/api/v1/activities_controller.rb`:
```ruby
module Api
  module V1
    class ActivitiesController < ApplicationController
      # GET /api/v1/activities
      def index
        limit = params[:limit]&.to_i || 20

        activities = []

        # Practice sessions
        current_student.practice_sessions.order(created_at: :desc).limit(limit).each do |ps|
          activities << {
            id: "practice_#{ps.id}",
            type: 'practice_completed',
            description: "Completed #{ps.subject} practice with #{ps.correct_answers}/#{ps.total_problems} correct",
            created_at: ps.created_at
          }
        end

        # Tutoring sessions
        current_student.tutoring_sessions.order(created_at: :desc).limit(limit).each do |ts|
          activities << {
            id: "session_#{ts.id}",
            type: 'session_completed',
            description: "Had a #{ts.subject} session#{ts.tutor ? " with #{ts.tutor.first_name}" : ''}",
            created_at: ts.created_at
          }
        end

        # Conversations
        current_student.conversations.order(updated_at: :desc).limit(limit).each do |c|
          activities << {
            id: "conversation_#{c.id}",
            type: 'conversation',
            description: "AI chat about #{c.subject || 'general topics'}",
            created_at: c.updated_at
          }
        end

        # Goal completions
        current_student.learning_goals.where(status: :completed).order(completed_at: :desc).limit(limit).each do |g|
          activities << {
            id: "goal_#{g.id}",
            type: 'goal_completed',
            description: "Completed goal: #{g.title}",
            created_at: g.completed_at
          }
        end

        # Sort and limit
        activities = activities.sort_by { |a| a[:created_at] }.reverse.first(limit)

        render json: activities
      end
    end
  end
end
```

### Serializers
Create `backend/app/serializers/learning_profile_serializer.rb`:
```ruby
class LearningProfileSerializer
  def initialize(profile, detailed: false)
    @profile = profile
    @detailed = detailed
  end

  def as_json(*)
    data = {
      id: @profile.id,
      subject: @profile.subject,
      proficiency_level: @profile.proficiency_level,
      strengths: @profile.strengths || [],
      weaknesses: @profile.weaknesses || [],
      last_assessed_at: @profile.last_assessed_at
    }

    if @detailed
      data[:knowledge_gaps] = @profile.knowledge_gaps || []
      data[:practice_stats] = practice_stats
      data[:session_count] = session_count
    end

    data
  end

  private

  def practice_stats
    sessions = @profile.student.practice_sessions.where(subject: @profile.subject)
    return {} if sessions.empty?

    {
      total_sessions: sessions.count,
      total_problems: sessions.sum(:total_problems),
      average_accuracy: calculate_accuracy(sessions)
    }
  end

  def calculate_accuracy(sessions)
    total = sessions.sum(:total_problems)
    return 0 if total.zero?
    ((sessions.sum(:correct_answers).to_f / total) * 100).round
  end

  def session_count
    @profile.student.tutoring_sessions.where(subject: @profile.subject).count
  end
end
```

Create `backend/app/serializers/learning_goal_serializer.rb`:
```ruby
class LearningGoalSerializer
  def initialize(goal, detailed: false)
    @goal = goal
    @detailed = detailed
  end

  def as_json(*)
    data = {
      id: @goal.id,
      subject: @goal.subject,
      title: @goal.title,
      description: @goal.description,
      status: @goal.status,
      progress_percentage: @goal.progress_percentage,
      target_date: @goal.target_date,
      milestones: @goal.milestones || [],
      created_at: @goal.created_at,
      completed_at: @goal.completed_at
    }

    if @detailed
      data[:suggested_next_goals] = @goal.suggested_next_goals || []
      data[:target_outcome] = @goal.target_outcome
      data[:related_practice_sessions] = related_practice_count
      data[:related_tutoring_sessions] = related_tutoring_count
    end

    data
  end

  private

  def related_practice_count
    @goal.student.practice_sessions
      .where(subject: @goal.subject)
      .where('created_at >= ?', @goal.created_at)
      .count
  end

  def related_tutoring_count
    @goal.student.tutoring_sessions
      .where(subject: @goal.subject)
      .where('created_at >= ?', @goal.created_at)
      .count
  end
end
```

---

## Task 15: Parent Dashboard View

### Parent Authentication
Create `backend/app/controllers/api/v1/parent/base_controller.rb`:
```ruby
module Api
  module V1
    module Parent
      class BaseController < ApplicationController
        skip_before_action :authenticate_request
        before_action :authenticate_parent

        private

        def authenticate_parent
          token = extract_token
          payload = JwtService.decode(token)

          if payload && payload[:parent_id]
            @current_parent = Parent.find_by(id: payload[:parent_id])
          end

          render json: { error: 'Unauthorized' }, status: :unauthorized unless @current_parent
        end

        def current_parent
          @current_parent
        end

        def extract_token
          header = request.headers['Authorization']
          header&.split(' ')&.last
        end
      end
    end
  end
end
```

### Parent Model & Migration
Create `backend/db/migrate/xxx_create_parents.rb`:
```ruby
class CreateParents < ActiveRecord::Migration[7.0]
  def change
    create_table :parents do |t|
      t.string :external_id, null: false, index: { unique: true }
      t.string :email, null: false
      t.string :first_name
      t.string :last_name
      t.jsonb :notification_preferences, default: {}
      t.timestamps
    end

    create_table :parent_students do |t|
      t.references :parent, null: false, foreign_key: true
      t.references :student, null: false, foreign_key: true
      t.string :relationship, default: 'parent'
      t.timestamps
    end

    add_index :parent_students, [:parent_id, :student_id], unique: true
  end
end
```

Create `backend/app/models/parent.rb`:
```ruby
class Parent < ApplicationRecord
  has_many :parent_students
  has_many :students, through: :parent_students

  validates :external_id, presence: true, uniqueness: true
  validates :email, presence: true
end
```

### Parent Dashboard Controller
Create `backend/app/controllers/api/v1/parent/dashboard_controller.rb`:
```ruby
module Api
  module V1
    module Parent
      class DashboardController < BaseController
        # GET /api/v1/parent/dashboard
        def index
          students_data = current_parent.students.map do |student|
            {
              id: student.id,
              name: "#{student.first_name} #{student.last_name}",
              summary: student_summary(student),
              recent_activity: recent_activity(student),
              goals: active_goals(student),
              recommendations: recommendations(student)
            }
          end

          render json: { students: students_data }
        end

        # GET /api/v1/parent/dashboard/student/:id
        def student_detail
          student = current_parent.students.find(params[:id])

          render json: {
            student: {
              id: student.id,
              name: "#{student.first_name} #{student.last_name}",
              summary: student_summary(student),
              weekly_report: weekly_report(student),
              learning_profiles: learning_profiles(student),
              goals: all_goals(student),
              activity_timeline: activity_timeline(student),
              tutor_sessions: upcoming_sessions(student)
            }
          }
        end

        # GET /api/v1/parent/dashboard/weekly_report/:student_id
        def weekly_report_detail
          student = current_parent.students.find(params[:student_id])

          render json: generate_weekly_report(student)
        end

        private

        def student_summary(student)
          {
            total_sessions_this_month: student.tutoring_sessions.where('created_at > ?', 30.days.ago).count,
            practice_problems_this_week: student.practice_sessions.where('created_at > ?', 7.days.ago).sum(:total_problems),
            average_accuracy: calculate_accuracy(student),
            active_goals: student.learning_goals.where(status: :active).count,
            current_streak: calculate_streak(student),
            engagement_score: calculate_engagement(student)
          }
        end

        def recent_activity(student, limit: 5)
          activities = []

          student.practice_sessions.order(created_at: :desc).limit(limit).each do |ps|
            activities << {
              type: 'practice',
              description: "#{ps.subject} practice: #{ps.correct_answers}/#{ps.total_problems} correct",
              timestamp: ps.created_at
            }
          end

          student.tutoring_sessions.order(created_at: :desc).limit(limit).each do |ts|
            activities << {
              type: 'session',
              description: "#{ts.subject} session with #{ts.tutor&.first_name || 'tutor'}",
              timestamp: ts.started_at
            }
          end

          activities.sort_by { |a| a[:timestamp] }.reverse.first(limit)
        end

        def active_goals(student)
          student.learning_goals.where(status: :active).map do |goal|
            {
              id: goal.id,
              title: goal.title,
              subject: goal.subject,
              progress: goal.progress_percentage,
              target_date: goal.target_date
            }
          end
        end

        def recommendations(student)
          recs = []

          # Low engagement
          tracker = Retention::EngagementTracker.new(student: student)
          if tracker.engagement_score < 50
            recs << {
              type: 'engagement',
              priority: 'high',
              message: "#{student.first_name}'s engagement has dropped. Consider scheduling a tutoring session.",
              action: 'book_session'
            }
          end

          # Stalled goals
          stalled = student.learning_goals.where(status: :active).where('updated_at < ?', 14.days.ago)
          if stalled.any?
            recs << {
              type: 'goal_stalled',
              priority: 'medium',
              message: "#{student.first_name} hasn't made progress on '#{stalled.first.title}' in 2 weeks.",
              action: 'view_goal',
              goal_id: stalled.first.id
            }
          end

          # Struggling topics
          profile = student.learning_profiles.order(proficiency_level: :asc).first
          if profile && profile.weaknesses&.any?
            recs << {
              type: 'weakness',
              priority: 'low',
              message: "#{student.first_name} could use help with #{profile.weaknesses.first} in #{profile.subject}.",
              action: 'book_session',
              subject: profile.subject
            }
          end

          recs
        end

        def weekly_report(student)
          week_start = 1.week.ago.beginning_of_week

          {
            period: "#{week_start.strftime('%b %d')} - #{Date.current.strftime('%b %d')}",
            sessions_attended: student.tutoring_sessions.where('started_at > ?', week_start).count,
            practice_problems: student.practice_sessions.where('created_at > ?', week_start).sum(:total_problems),
            accuracy: weekly_accuracy(student, week_start),
            time_spent_minutes: weekly_time_spent(student, week_start),
            goals_progress: goals_progress_this_week(student, week_start),
            highlights: weekly_highlights(student, week_start)
          }
        end

        def learning_profiles(student)
          student.learning_profiles.map do |p|
            {
              subject: p.subject,
              proficiency_level: p.proficiency_level,
              strengths: p.strengths || [],
              weaknesses: p.weaknesses || []
            }
          end
        end

        def all_goals(student)
          student.learning_goals.order(created_at: :desc).map do |g|
            {
              id: g.id,
              title: g.title,
              subject: g.subject,
              status: g.status,
              progress: g.progress_percentage,
              target_date: g.target_date,
              created_at: g.created_at,
              completed_at: g.completed_at
            }
          end
        end

        def activity_timeline(student, limit: 20)
          activities = []

          student.practice_sessions.order(created_at: :desc).limit(limit).each do |ps|
            activities << {
              type: 'practice',
              subject: ps.subject,
              details: "#{ps.correct_answers}/#{ps.total_problems} correct (#{((ps.correct_answers.to_f / ps.total_problems) * 100).round}%)",
              timestamp: ps.created_at
            }
          end

          student.tutoring_sessions.order(created_at: :desc).limit(limit).each do |ts|
            activities << {
              type: 'session',
              subject: ts.subject,
              details: ts.summary || "Session with #{ts.tutor&.first_name}",
              timestamp: ts.started_at
            }
          end

          student.learning_goals.where(status: :completed).each do |g|
            activities << {
              type: 'goal_completed',
              subject: g.subject,
              details: "Completed: #{g.title}",
              timestamp: g.completed_at
            }
          end

          activities.sort_by { |a| a[:timestamp] }.reverse.first(limit)
        end

        def upcoming_sessions(student)
          # Would integrate with Nerdy booking system
          []
        end

        def calculate_accuracy(student)
          sessions = student.practice_sessions.where('created_at > ?', 30.days.ago)
          return 0 if sessions.empty? || sessions.sum(:total_problems).zero?

          ((sessions.sum(:correct_answers).to_f / sessions.sum(:total_problems)) * 100).round
        end

        def calculate_streak(student)
          # Simplified streak calculation
          dates = student.practice_sessions.pluck(:created_at).map(&:to_date).uniq.sort.reverse
          return 0 if dates.empty? || dates.first != Date.current

          streak = 1
          dates.each_cons(2) do |current, previous|
            break unless current - previous == 1
            streak += 1
          end
          streak
        end

        def calculate_engagement(student)
          Retention::EngagementTracker.new(student: student).engagement_score
        end

        def weekly_accuracy(student, week_start)
          sessions = student.practice_sessions.where('created_at > ?', week_start)
          return 0 if sessions.empty? || sessions.sum(:total_problems).zero?

          ((sessions.sum(:correct_answers).to_f / sessions.sum(:total_problems)) * 100).round
        end

        def weekly_time_spent(student, week_start)
          practice_time = student.practice_sessions.where('created_at > ?', week_start).sum(:time_spent_seconds) / 60

          session_time = student.tutoring_sessions.where('started_at > ?', week_start).sum do |s|
            next 0 unless s.started_at && s.ended_at
            ((s.ended_at - s.started_at) / 60).round
          end

          practice_time + session_time
        end

        def goals_progress_this_week(student, week_start)
          student.learning_goals.where(status: :active).map do |g|
            # Get progress change this week (simplified)
            {
              title: g.title,
              current_progress: g.progress_percentage,
              change: rand(5..15) # Would calculate actual change
            }
          end
        end

        def weekly_highlights(student, week_start)
          highlights = []

          # Best practice session
          best = student.practice_sessions.where('created_at > ?', week_start).order(Arel.sql('correct_answers::float / NULLIF(total_problems, 0) DESC')).first
          if best
            accuracy = ((best.correct_answers.to_f / best.total_problems) * 100).round
            highlights << "Best practice session: #{accuracy}% accuracy in #{best.subject}"
          end

          # Goal completed
          completed = student.learning_goals.where(status: :completed).where('completed_at > ?', week_start).first
          highlights << "Completed goal: #{completed.title}" if completed

          # New session
          session = student.tutoring_sessions.where('started_at > ?', week_start).first
          highlights << "Had a #{session.subject} tutoring session" if session

          highlights
        end

        def generate_weekly_report(student)
          week_start = 1.week.ago.beginning_of_week
          report = weekly_report(student)

          # Generate AI summary
          client = OpenAI::Client.new
          prompt = <<~PROMPT
            Generate a brief, encouraging weekly report summary for a parent about their child's learning progress.

            Student: #{student.first_name}
            Sessions this week: #{report[:sessions_attended]}
            Practice problems: #{report[:practice_problems]}
            Average accuracy: #{report[:accuracy]}%
            Time spent: #{report[:time_spent_minutes]} minutes

            Highlights:
            #{report[:highlights].join("\n")}

            Write 2-3 sentences summarizing the week and 1 sentence of encouragement.
          PROMPT

          response = client.chat(
            parameters: {
              model: 'gpt-4-turbo-preview',
              messages: [{ role: 'user', content: prompt }],
              max_tokens: 200
            }
          )

          report[:ai_summary] = response.dig('choices', 0, 'message', 'content')
          report
        end
      end
    end
  end
end
```

### Parent Frontend Components
Create `frontend/src/pages/ParentDashboard.tsx`:
```typescript
import React, { useState, useEffect } from 'react';
import { api } from '../api/client';

interface StudentSummary {
  id: number;
  name: string;
  summary: {
    total_sessions_this_month: number;
    practice_problems_this_week: number;
    average_accuracy: number;
    active_goals: number;
    current_streak: number;
    engagement_score: number;
  };
  recent_activity: Array<{
    type: string;
    description: string;
    timestamp: string;
  }>;
  goals: Array<{
    id: number;
    title: string;
    subject: string;
    progress: number;
  }>;
  recommendations: Array<{
    type: string;
    priority: string;
    message: string;
    action: string;
  }>;
}

export default function ParentDashboard() {
  const [students, setStudents] = useState<StudentSummary[]>([]);
  const [selectedStudent, setSelectedStudent] = useState<number | null>(null);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    loadDashboard();
  }, []);

  const loadDashboard = async () => {
    const response = await api.get('/api/v1/parent/dashboard');
    setStudents(response.data.students);
    setIsLoading(false);
  };

  if (isLoading) {
    return (
      <div className="min-h-screen bg-gray-50 flex items-center justify-center">
        <div className="animate-spin w-8 h-8 border-4 border-indigo-600 border-t-transparent rounded-full" />
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gray-50">
      <div className="max-w-7xl mx-auto px-4 py-8">
        <h1 className="text-3xl font-bold text-gray-800 mb-8">Parent Dashboard</h1>

        {students.map((student) => (
          <div key={student.id} className="mb-8">
            <div className="bg-white rounded-xl shadow-sm p-6">
              <h2 className="text-xl font-semibold text-gray-800 mb-4">{student.name}</h2>

              {/* Stats Grid */}
              <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-6">
                <StatCard
                  label="Sessions This Month"
                  value={student.summary.total_sessions_this_month}
                  icon="👨‍🏫"
                />
                <StatCard
                  label="Practice Problems"
                  value={student.summary.practice_problems_this_week}
                  icon="✏️"
                />
                <StatCard
                  label="Accuracy"
                  value={`${student.summary.average_accuracy}%`}
                  icon="🎯"
                />
                <StatCard
                  label="Day Streak"
                  value={student.summary.current_streak}
                  icon="🔥"
                />
              </div>

              {/* Engagement Score */}
              <div className="mb-6">
                <div className="flex items-center justify-between mb-2">
                  <span className="text-sm font-medium text-gray-600">Engagement Score</span>
                  <span className="text-sm font-bold text-indigo-600">{student.summary.engagement_score}/100</span>
                </div>
                <div className="w-full h-3 bg-gray-200 rounded-full">
                  <div
                    className={`h-full rounded-full ${
                      student.summary.engagement_score >= 70 ? 'bg-green-500' :
                      student.summary.engagement_score >= 40 ? 'bg-yellow-500' : 'bg-red-500'
                    }`}
                    style={{ width: `${student.summary.engagement_score}%` }}
                  />
                </div>
              </div>

              {/* Recommendations */}
              {student.recommendations.length > 0 && (
                <div className="mb-6">
                  <h3 className="text-lg font-medium text-gray-800 mb-3">Recommendations</h3>
                  <div className="space-y-2">
                    {student.recommendations.map((rec, i) => (
                      <div
                        key={i}
                        className={`p-3 rounded-lg ${
                          rec.priority === 'high' ? 'bg-red-50 border-l-4 border-red-500' :
                          rec.priority === 'medium' ? 'bg-yellow-50 border-l-4 border-yellow-500' :
                          'bg-blue-50 border-l-4 border-blue-500'
                        }`}
                      >
                        <p className="text-sm text-gray-700">{rec.message}</p>
                      </div>
                    ))}
                  </div>
                </div>
              )}

              {/* Active Goals */}
              <div className="mb-6">
                <h3 className="text-lg font-medium text-gray-800 mb-3">Active Goals</h3>
                <div className="space-y-3">
                  {student.goals.map((goal) => (
                    <div key={goal.id} className="flex items-center gap-4">
                      <div className="flex-1">
                        <div className="flex justify-between mb-1">
                          <span className="text-sm font-medium text-gray-700">{goal.title}</span>
                          <span className="text-sm text-gray-500">{goal.progress}%</span>
                        </div>
                        <div className="w-full h-2 bg-gray-200 rounded-full">
                          <div
                            className="h-full bg-indigo-600 rounded-full"
                            style={{ width: `${goal.progress}%` }}
                          />
                        </div>
                      </div>
                    </div>
                  ))}
                </div>
              </div>

              {/* Recent Activity */}
              <div>
                <h3 className="text-lg font-medium text-gray-800 mb-3">Recent Activity</h3>
                <div className="space-y-2">
                  {student.recent_activity.map((activity, i) => (
                    <div key={i} className="flex items-center gap-3 text-sm">
                      <span>{activity.type === 'practice' ? '✏️' : '👨‍🏫'}</span>
                      <span className="text-gray-600">{activity.description}</span>
                      <span className="text-gray-400 ml-auto">
                        {new Date(activity.timestamp).toLocaleDateString()}
                      </span>
                    </div>
                  ))}
                </div>
              </div>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

function StatCard({ label, value, icon }: { label: string; value: string | number; icon: string }) {
  return (
    <div className="bg-gray-50 rounded-lg p-4">
      <div className="flex items-center gap-2">
        <span className="text-xl">{icon}</span>
        <div>
          <div className="text-xl font-bold text-gray-800">{value}</div>
          <div className="text-xs text-gray-500">{label}</div>
        </div>
      </div>
    </div>
  );
}
```

---

## Task 17: API Rate Limiting and Caching

### Redis Configuration
Create `backend/config/initializers/redis.rb`:
```ruby
REDIS = Redis.new(url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0'))

# For Rails cache
Rails.application.config.cache_store = :redis_cache_store, {
  url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/1'),
  expires_in: 1.hour
}
```

### Rate Limiter Middleware
Create `backend/app/middleware/rate_limiter.rb`:
```ruby
class RateLimiter
  LIMITS = {
    default: { requests: 100, period: 60 },           # 100 req/min
    ai_conversation: { requests: 20, period: 60 },    # 20 req/min
    ai_practice: { requests: 10, period: 60 },        # 10 req/min
    auth: { requests: 5, period: 60 }                 # 5 req/min
  }.freeze

  def initialize(app)
    @app = app
  end

  def call(env)
    request = Rack::Request.new(env)

    # Skip rate limiting for non-API routes
    return @app.call(env) unless request.path.start_with?('/api/')

    # Determine limit type based on path
    limit_type = determine_limit_type(request.path)
    limits = LIMITS[limit_type]

    # Get identifier (user ID from JWT or IP)
    identifier = extract_identifier(request)

    # Check rate limit
    key = "rate_limit:#{limit_type}:#{identifier}"

    current_count = REDIS.get(key).to_i

    if current_count >= limits[:requests]
      return rate_limit_exceeded_response(limits)
    end

    # Increment counter
    REDIS.multi do |multi|
      multi.incr(key)
      multi.expire(key, limits[:period]) if current_count.zero?
    end

    # Add rate limit headers
    status, headers, response = @app.call(env)

    headers['X-RateLimit-Limit'] = limits[:requests].to_s
    headers['X-RateLimit-Remaining'] = (limits[:requests] - current_count - 1).to_s
    headers['X-RateLimit-Reset'] = (Time.now.to_i + REDIS.ttl(key)).to_s

    [status, headers, response]
  end

  private

  def determine_limit_type(path)
    case path
    when %r{/api/v1/conversations/.*/messages}
      :ai_conversation
    when %r{/api/v1/practice_sessions}
      :ai_practice
    when %r{/api/v1/auth}
      :auth
    else
      :default
    end
  end

  def extract_identifier(request)
    token = request.get_header('HTTP_AUTHORIZATION')&.split(' ')&.last
    if token
      payload = JwtService.decode(token)
      return "user:#{payload[:student_id]}" if payload
    end
    "ip:#{request.ip}"
  end

  def rate_limit_exceeded_response(limits)
    [
      429,
      {
        'Content-Type' => 'application/json',
        'Retry-After' => limits[:period].to_s
      },
      [{ error: 'Rate limit exceeded', retry_after: limits[:period] }.to_json]
    ]
  end
end
```

Add to `backend/config/application.rb`:
```ruby
config.middleware.use RateLimiter
```

### AI Response Caching Service
Create `backend/app/services/ai/cache_service.rb`:
```ruby
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
```

### Update Memory Service with Caching
Update `backend/app/services/ai/memory_service.rb` to use caching:
```ruby
# Add to existing MemoryService class

def generate_embedding(text)
  AI::CacheService.cache_embedding(text) do
    response = @client.embeddings(
      parameters: {
        model: EMBEDDING_MODEL,
        input: text.truncate(8000)
      }
    )
    response.dig('data', 0, 'embedding')
  end
end

def get_subject_context(subject, limit: 10)
  AI::CacheService.cache_subject_context(student_id: @student.id, subject: subject) do
    @student.knowledge_nodes
      .where(subject: subject)
      .order(created_at: :desc)
      .limit(limit)
      .to_a
  end
end
```

### AI Cost Tracking
Create `backend/app/services/ai/cost_tracker.rb`:
```ruby
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
```

### AI Usage Log Migration
Create `backend/db/migrate/xxx_create_ai_usage_logs.rb`:
```ruby
class CreateAiUsageLogs < ActiveRecord::Migration[7.0]
  def change
    create_table :ai_usage_logs do |t|
      t.references :student, foreign_key: true
      t.string :model, null: false
      t.string :operation
      t.integer :input_tokens, default: 0
      t.integer :output_tokens, default: 0
      t.decimal :cost_usd, precision: 10, scale: 6, default: 0
      t.timestamps
    end

    add_index :ai_usage_logs, :created_at
    add_index :ai_usage_logs, [:student_id, :created_at]
  end
end
```

---

## Task 19: Analytics and Metrics Collection

### Analytics Service
Create `backend/app/services/analytics/metrics_service.rb`:
```ruby
module Analytics
  class MetricsService
    class << self
      # Track an event
      def track(event_name, properties = {})
        AnalyticsEvent.create!(
          event_name: event_name,
          student_id: properties.delete(:student_id),
          properties: properties,
          occurred_at: Time.current
        )

        # Also send to external analytics if configured
        send_to_external(event_name, properties) if external_analytics_enabled?
      end

      # Conversation metrics
      def conversation_started(conversation)
        track('conversation_started', {
          student_id: conversation.student_id,
          conversation_id: conversation.id,
          subject: conversation.subject
        })
      end

      def message_sent(message)
        track('message_sent', {
          student_id: message.conversation.student_id,
          conversation_id: message.conversation_id,
          role: message.role,
          message_length: message.content.length
        })
      end

      # Practice metrics
      def practice_started(session)
        track('practice_started', {
          student_id: session.student_id,
          session_id: session.id,
          subject: session.subject,
          session_type: session.session_type,
          problem_count: session.total_problems
        })
      end

      def practice_completed(session)
        track('practice_completed', {
          student_id: session.student_id,
          session_id: session.id,
          subject: session.subject,
          accuracy: session.total_problems > 0 ? (session.correct_answers.to_f / session.total_problems * 100).round : 0,
          time_spent: session.time_spent_seconds,
          struggled_topics: session.struggled_topics
        })
      end

      # Goal metrics
      def goal_created(goal)
        track('goal_created', {
          student_id: goal.student_id,
          goal_id: goal.id,
          subject: goal.subject
        })
      end

      def goal_completed(goal)
        days_to_complete = goal.completed_at ? (goal.completed_at.to_date - goal.created_at.to_date).to_i : nil

        track('goal_completed', {
          student_id: goal.student_id,
          goal_id: goal.id,
          subject: goal.subject,
          days_to_complete: days_to_complete
        })
      end

      def goal_progress_updated(goal, old_progress, new_progress)
        track('goal_progress', {
          student_id: goal.student_id,
          goal_id: goal.id,
          old_progress: old_progress,
          new_progress: new_progress,
          delta: new_progress - old_progress
        })
      end

      # Engagement metrics
      def session_booked(student, subject)
        track('session_booked', {
          student_id: student.id,
          subject: subject
        })
      end

      def tutor_handoff(conversation, reasons)
        track('tutor_handoff', {
          student_id: conversation.student_id,
          conversation_id: conversation.id,
          subject: conversation.subject,
          reasons: reasons
        })
      end

      def nudge_sent(student, nudge_type)
        track('nudge_sent', {
          student_id: student.id,
          nudge_type: nudge_type
        })
      end

      def nudge_acted(student, nudge_type, action)
        track('nudge_acted', {
          student_id: student.id,
          nudge_type: nudge_type,
          action: action
        })
      end

      # Aggregation queries
      def daily_active_users(date: Date.current)
        AnalyticsEvent.where('DATE(occurred_at) = ?', date)
          .distinct
          .count(:student_id)
      end

      def weekly_retention(cohort_start:)
        cohort_students = Student.where('DATE(created_at) = ?', cohort_start).pluck(:id)
        return 0 if cohort_students.empty?

        retained = AnalyticsEvent
          .where(student_id: cohort_students)
          .where('occurred_at > ?', cohort_start + 7.days)
          .distinct
          .count(:student_id)

        (retained.to_f / cohort_students.length * 100).round(1)
      end

      def conversion_funnel(period: 30.days)
        start_date = period.ago

        {
          signups: Student.where('created_at > ?', start_date).count,
          first_conversation: AnalyticsEvent.where(event_name: 'conversation_started')
            .where('occurred_at > ?', start_date)
            .distinct.count(:student_id),
          first_practice: AnalyticsEvent.where(event_name: 'practice_started')
            .where('occurred_at > ?', start_date)
            .distinct.count(:student_id),
          goal_created: AnalyticsEvent.where(event_name: 'goal_created')
            .where('occurred_at > ?', start_date)
            .distinct.count(:student_id),
          session_booked: AnalyticsEvent.where(event_name: 'session_booked')
            .where('occurred_at > ?', start_date)
            .distinct.count(:student_id)
        }
      end

      def learning_outcomes(student_id, subject: nil)
        profiles = LearningProfile.where(student_id: student_id)
        profiles = profiles.where(subject: subject) if subject

        profiles.map do |profile|
          practice_sessions = PracticeSession.where(student_id: student_id, subject: profile.subject)

          {
            subject: profile.subject,
            proficiency_change: calculate_proficiency_trend(practice_sessions),
            accuracy_trend: calculate_accuracy_trend(practice_sessions),
            time_invested: practice_sessions.sum(:time_spent_seconds) / 60,
            problems_solved: practice_sessions.sum(:total_problems)
          }
        end
      end

      private

      def external_analytics_enabled?
        ENV['ANALYTICS_API_KEY'].present?
      end

      def send_to_external(event_name, properties)
        # Integration with Mixpanel, Amplitude, Segment, etc.
        # HTTParty.post(...)
      end

      def calculate_proficiency_trend(sessions)
        return 0 if sessions.count < 2

        recent = sessions.order(created_at: :desc).limit(5)
        older = sessions.order(created_at: :desc).offset(5).limit(5)

        return 0 if older.empty?

        recent_avg = avg_accuracy(recent)
        older_avg = avg_accuracy(older)

        ((recent_avg - older_avg) * 100).round(1)
      end

      def calculate_accuracy_trend(sessions)
        sessions.order(:created_at).map do |s|
          {
            date: s.created_at.to_date,
            accuracy: s.total_problems > 0 ? (s.correct_answers.to_f / s.total_problems * 100).round : 0
          }
        end
      end

      def avg_accuracy(sessions)
        total_correct = sessions.sum(:correct_answers)
        total_problems = sessions.sum(:total_problems)
        return 0 if total_problems.zero?
        total_correct.to_f / total_problems
      end
    end
  end
end
```

### Analytics Events Migration
Create `backend/db/migrate/xxx_create_analytics_events.rb`:
```ruby
class CreateAnalyticsEvents < ActiveRecord::Migration[7.0]
  def change
    create_table :analytics_events do |t|
      t.string :event_name, null: false
      t.references :student, foreign_key: true
      t.jsonb :properties, default: {}
      t.datetime :occurred_at, null: false
      t.timestamps
    end

    add_index :analytics_events, :event_name
    add_index :analytics_events, :occurred_at
    add_index :analytics_events, [:student_id, :event_name, :occurred_at]
  end
end
```

### Analytics Dashboard Controller
Create `backend/app/controllers/api/v1/admin/analytics_controller.rb`:
```ruby
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
```

---

## Routes Update

Add to `backend/config/routes.rb`:
```ruby
namespace :api do
  namespace :v1 do
    # Learning Profiles & Goals
    resources :learning_profiles, only: [:index, :show, :update] do
      collection do
        get :summary
      end
    end

    resources :learning_goals do
      member do
        get :suggestions
        post :evaluate_completion
        post :milestones, to: 'learning_goals#add_milestone'
        put 'milestones/:milestone_id', to: 'learning_goals#update_milestone'
      end
    end

    # Stats & Activities
    get 'stats', to: 'stats#index'
    get 'stats/weekly', to: 'stats#weekly'
    get 'activities', to: 'activities#index'

    # Parent Dashboard
    namespace :parent do
      get 'dashboard', to: 'dashboard#index'
      get 'dashboard/student/:id', to: 'dashboard#student_detail'
      get 'dashboard/weekly_report/:student_id', to: 'dashboard#weekly_report_detail'
    end

    # Admin Analytics
    namespace :admin do
      get 'analytics/overview', to: 'analytics#overview'
      get 'analytics/engagement', to: 'analytics#engagement'
      get 'analytics/learning', to: 'analytics#learning'
    end
  end
end
```

---

## Validation Checklist

- [ ] Learning profiles CRUD works
- [ ] Learning goals with milestones work
- [ ] Stats endpoint returns correct data
- [ ] Parent dashboard loads student data
- [ ] Rate limiting returns 429 when exceeded
- [ ] Caching reduces API calls (check Redis)
- [ ] AI cost tracking logs usage
- [ ] Analytics events are recorded
- [ ] Admin analytics dashboard works

Execute this entire implementation.
