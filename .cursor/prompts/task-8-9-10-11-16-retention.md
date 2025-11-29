# One-Shot Prompt: Retention & Engagement Features (Tasks 8, 9, 10, 11, 16)

## Context
Building the retention-focused features for the Nerdy AI Study Companion. These systems address the 52% "goal achieved" churn and drive students back to human tutors when needed. Assumes Tasks 1-7 (setup, database, auth, AI core) are complete.

## Your Mission
Implement the complete retention system in a single pass:
- **Task 8:** Session Recording Integration
- **Task 9:** Goal Completion Detection System
- **Task 10:** Student Engagement Nudge System
- **Task 11:** Human Tutor Handoff System
- **Task 16:** Tutor Preparation Brief Generator

---

## Task 8: Session Recording Integration

Connect to Nerdy's existing session recordings and extract learning context.

### Nerdy Platform Client
Create `backend/app/services/nerdy/platform_client.rb`:
```ruby
module Nerdy
  class PlatformClient
    BASE_URL = ENV.fetch('NERDY_PLATFORM_URL', 'https://api.nerdy.com')

    def initialize
      @connection = Faraday.new(url: BASE_URL) do |f|
        f.request :json
        f.response :json
        f.adapter Faraday.default_adapter
        f.headers['Authorization'] = "Bearer #{ENV['NERDY_API_KEY']}"
        f.headers['Content-Type'] = 'application/json'
      end
    end

    # Fetch session recordings for a student
    def get_student_sessions(external_student_id, since: 30.days.ago)
      response = @connection.get('/api/v1/sessions', {
        student_id: external_student_id,
        since: since.iso8601,
        include: 'transcript,recording'
      })

      return [] unless response.success?
      response.body['sessions'] || []
    end

    # Get single session details
    def get_session(external_session_id)
      response = @connection.get("/api/v1/sessions/#{external_session_id}")
      return nil unless response.success?
      response.body
    end

    # Get session transcript
    def get_transcript(external_session_id)
      response = @connection.get("/api/v1/sessions/#{external_session_id}/transcript")
      return nil unless response.success?
      response.body['transcript']
    end

    # Get available tutors for booking
    def get_available_tutors(subject:, datetime:, duration: 60)
      response = @connection.get('/api/v1/tutors/availability', {
        subject: subject,
        datetime: datetime.iso8601,
        duration: duration
      })

      return [] unless response.success?
      response.body['tutors'] || []
    end

    # Create a booking
    def create_booking(student_id:, tutor_id:, subject:, datetime:, notes: nil)
      response = @connection.post('/api/v1/bookings', {
        student_id: student_id,
        tutor_id: tutor_id,
        subject: subject,
        scheduled_at: datetime.iso8601,
        notes: notes
      })

      response.success? ? response.body : nil
    end

    # Send notification to student
    def send_notification(student_id:, type:, title:, message:, data: {})
      response = @connection.post('/api/v1/notifications', {
        student_id: student_id,
        notification_type: type,
        title: title,
        message: message,
        data: data
      })

      response.success?
    end
  end
end
```

### Session Sync Service
Create `backend/app/services/nerdy/session_sync_service.rb`:
```ruby
module Nerdy
  class SessionSyncService
    def initialize(student:)
      @student = student
      @client = PlatformClient.new
      @memory_service = AI::MemoryService.new(student: student)
    end

    # Sync all recent sessions for a student
    def sync_recent_sessions(since: 30.days.ago)
      external_sessions = @client.get_student_sessions(@student.external_id, since: since)

      external_sessions.map do |session_data|
        sync_session(session_data)
      end.compact
    end

    # Sync a single session
    def sync_session(session_data)
      # Find or create local session record
      session = TutoringSession.find_or_initialize_by(
        external_session_id: session_data['id']
      )

      # Skip if already fully processed
      return session if session.persisted? && session.summary.present?

      # Find or create tutor
      tutor = sync_tutor(session_data['tutor']) if session_data['tutor']

      # Update session details
      session.assign_attributes(
        student: @student,
        tutor: tutor,
        subject: session_data['subject'],
        started_at: session_data['started_at'],
        ended_at: session_data['ended_at'],
        transcript_url: session_data['transcript_url']
      )

      session.save!

      # Process transcript asynchronously
      ProcessSessionJob.perform_later(session.id) if session.transcript_url.present?

      session
    end

    private

    def sync_tutor(tutor_data)
      Tutor.find_or_create_by(external_id: tutor_data['id']) do |t|
        t.email = tutor_data['email']
        t.first_name = tutor_data['first_name']
        t.last_name = tutor_data['last_name']
        t.subjects = tutor_data['subjects'] || []
      end
    end
  end
end
```

### Session Sync Job
Create `backend/app/jobs/sync_student_sessions_job.rb`:
```ruby
class SyncStudentSessionsJob < ApplicationJob
  queue_as :default

  def perform(student_id)
    student = Student.find(student_id)
    service = Nerdy::SessionSyncService.new(student: student)
    service.sync_recent_sessions
  end
end
```

### Transcript Processing (Enhanced)
Update `backend/app/jobs/process_session_job.rb`:
```ruby
class ProcessSessionJob < ApplicationJob
  queue_as :default
  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  def perform(session_id)
    session = TutoringSession.find(session_id)
    return if session.summary.present? # Already processed

    # Fetch transcript
    client = Nerdy::PlatformClient.new
    transcript = client.get_transcript(session.external_session_id)

    return unless transcript.present?

    # Analyze with AI
    analysis = analyze_transcript(transcript, session.subject)

    # Update session
    session.update!(
      summary: analysis[:summary],
      topics_covered: analysis[:topics],
      key_concepts: analysis[:concepts]
    )

    # Store in vector memory
    store_in_memory(session, analysis)

    # Update learning profile
    update_learning_profile(session, analysis)

    # Check for goal progress
    check_goal_progress(session, analysis)
  end

  private

  def analyze_transcript(transcript, subject)
    client = OpenAI::Client.new

    prompt = <<~PROMPT
      Analyze this #{subject} tutoring session transcript:

      #{transcript.truncate(12000)}

      Provide JSON response:
      {
        "summary": "2-3 sentence summary",
        "topics": ["topic1", "topic2"],
        "concepts": ["concept1", "concept2"],
        "student_struggles": ["area1", "area2"],
        "mastery_demonstrated": ["concept1"],
        "recommended_practice": ["topic to practice"],
        "follow_up_topics": ["next topic to cover"],
        "engagement_level": "high|medium|low",
        "comprehension_score": 1-10
      }
    PROMPT

    response = client.chat(
      parameters: {
        model: 'gpt-4-turbo-preview',
        messages: [{ role: 'user', content: prompt }],
        response_format: { type: 'json_object' }
      }
    )

    JSON.parse(response.dig('choices', 0, 'message', 'content')).with_indifferent_access
  end

  def store_in_memory(session, analysis)
    memory_service = AI::MemoryService.new(student: session.student)

    content = <<~TEXT
      Tutoring session on #{session.subject} with #{session.tutor&.first_name || 'tutor'}
      Date: #{session.started_at&.strftime('%B %d, %Y')}

      Summary: #{analysis[:summary]}

      Topics covered: #{analysis[:topics].join(', ')}
      Key concepts: #{analysis[:concepts].join(', ')}
      Areas of struggle: #{analysis[:student_struggles].join(', ')}
      Demonstrated mastery: #{analysis[:mastery_demonstrated].join(', ')}
    TEXT

    memory_service.store_interaction(
      content: content,
      topic: session.subject,
      source_type: 'session',
      source_id: session.id,
      metadata: {
        tutor_id: session.tutor_id,
        comprehension_score: analysis[:comprehension_score],
        engagement_level: analysis[:engagement_level]
      }
    )
  end

  def update_learning_profile(session, analysis)
    profile = session.student.learning_profiles.find_or_create_by(subject: session.subject)

    # Update strengths (mastery demonstrated)
    current_strengths = profile.strengths || []
    new_strengths = (current_strengths + (analysis[:mastery_demonstrated] || [])).uniq.last(20)

    # Update weaknesses (struggles)
    current_weaknesses = profile.weaknesses || []
    # Remove weaknesses that are now mastered
    updated_weaknesses = current_weaknesses - (analysis[:mastery_demonstrated] || [])
    # Add new struggles
    updated_weaknesses = (updated_weaknesses + (analysis[:student_struggles] || [])).uniq.last(20)

    profile.update!(
      strengths: new_strengths,
      weaknesses: updated_weaknesses,
      last_assessed_at: Time.current
    )
  end

  def check_goal_progress(session, analysis)
    # Find active goals for this subject
    goals = session.student.learning_goals
      .where(subject: session.subject, status: :active)

    goals.each do |goal|
      GoalProgressService.new(goal: goal).check_and_update(
        session: session,
        analysis: analysis
      )
    end
  end
end
```

---

## Task 9: Goal Completion Detection System

Detect goal completion and suggest related subjects to reduce churn.

### Subject Recommendation Map
Create `backend/app/services/retention/subject_recommendations.rb`:
```ruby
module Retention
  class SubjectRecommendations
    # Mapping of completed subjects to recommended next subjects
    RECOMMENDATIONS = {
      'sat_prep' => {
        next_subjects: ['college_essays', 'study_skills', 'ap_courses', 'act_prep'],
        message: "Great job completing SAT prep! Many students find success continuing with college application support.",
        priority_order: ['college_essays', 'ap_courses', 'study_skills']
      },
      'act_prep' => {
        next_subjects: ['college_essays', 'study_skills', 'sat_prep', 'ap_courses'],
        message: "ACT prep complete! Consider getting help with college essays or AP courses.",
        priority_order: ['college_essays', 'ap_courses']
      },
      'chemistry' => {
        next_subjects: ['physics', 'biology', 'ap_chemistry', 'organic_chemistry'],
        message: "Chemistry mastered! Physics and biology are natural next steps for STEM success.",
        priority_order: ['physics', 'ap_chemistry', 'biology']
      },
      'physics' => {
        next_subjects: ['ap_physics', 'chemistry', 'calculus', 'engineering_prep'],
        message: "Physics complete! Consider AP Physics or strengthen your calculus foundation.",
        priority_order: ['ap_physics', 'calculus']
      },
      'algebra' => {
        next_subjects: ['geometry', 'algebra_2', 'pre_calculus', 'trigonometry'],
        message: "Algebra mastered! You're ready to tackle geometry or move to Algebra 2.",
        priority_order: ['geometry', 'algebra_2']
      },
      'geometry' => {
        next_subjects: ['algebra_2', 'trigonometry', 'pre_calculus'],
        message: "Geometry complete! Algebra 2 or trigonometry is your next math milestone.",
        priority_order: ['algebra_2', 'trigonometry']
      },
      'calculus' => {
        next_subjects: ['ap_calculus', 'statistics', 'linear_algebra', 'physics'],
        message: "Calculus done! AP Calculus or statistics will strengthen your math foundation.",
        priority_order: ['ap_calculus', 'statistics']
      },
      'biology' => {
        next_subjects: ['chemistry', 'ap_biology', 'anatomy', 'environmental_science'],
        message: "Biology mastered! Chemistry pairs perfectly, or dive deeper with AP Biology.",
        priority_order: ['chemistry', 'ap_biology']
      },
      'english' => {
        next_subjects: ['ap_english', 'creative_writing', 'sat_reading', 'literature'],
        message: "English skills strong! Consider AP English or focus on SAT reading.",
        priority_order: ['ap_english', 'sat_reading']
      },
      'spanish' => {
        next_subjects: ['ap_spanish', 'spanish_literature', 'french', 'latin'],
        message: "¡Muy bien! Ready for AP Spanish or explore another language?",
        priority_order: ['ap_spanish', 'french']
      }
    }.freeze

    def self.get_recommendations(subject)
      normalized = subject.to_s.downcase.gsub(/\s+/, '_')
      RECOMMENDATIONS[normalized] || default_recommendations(subject)
    end

    def self.default_recommendations(subject)
      {
        next_subjects: ['study_skills', 'test_prep', 'writing'],
        message: "Congratulations on completing #{subject}! Here are some ways to continue learning.",
        priority_order: ['study_skills', 'test_prep']
      }
    end
  end
end
```

### Goal Progress Service
Create `backend/app/services/retention/goal_progress_service.rb`:
```ruby
module Retention
  class GoalProgressService
    COMPLETION_THRESHOLD = 90 # percent

    def initialize(goal:)
      @goal = goal
      @student = goal.student
    end

    # Check progress after a session or practice
    def check_and_update(session: nil, analysis: nil, practice_session: nil)
      # Calculate progress from multiple signals
      progress = calculate_progress(session, analysis, practice_session)

      # Update goal
      @goal.update!(progress_percentage: progress)

      # Check for completion
      if progress >= COMPLETION_THRESHOLD && @goal.status != 'completed'
        complete_goal!
      end

      progress
    end

    # Manually trigger completion check
    def evaluate_completion
      signals = gather_completion_signals

      # Use AI to evaluate if goal is met
      evaluation = ai_evaluate_completion(signals)

      if evaluation[:is_complete]
        @goal.update!(progress_percentage: 100)
        complete_goal!
      else
        @goal.update!(progress_percentage: evaluation[:estimated_progress])
      end

      evaluation
    end

    private

    def calculate_progress(session, analysis, practice_session)
      scores = []

      # Session-based progress
      if session && analysis
        scores << analysis[:comprehension_score].to_i * 10 if analysis[:comprehension_score]
      end

      # Practice-based progress
      if practice_session
        accuracy = practice_session.correct_answers.to_f / practice_session.total_problems
        scores << (accuracy * 100).round
      end

      # Historical practice performance
      recent_practices = @student.practice_sessions
        .where(subject: @goal.subject)
        .where('created_at > ?', 30.days.ago)

      if recent_practices.any?
        avg_accuracy = recent_practices.average('correct_answers::float / NULLIF(total_problems, 0)') || 0
        scores << (avg_accuracy * 100).round
      end

      # Session count progress (attending sessions = progress)
      session_count = @student.tutoring_sessions
        .where(subject: @goal.subject)
        .where('created_at > ?', @goal.created_at)
        .count
      session_progress = [session_count * 15, 50].min # Cap at 50% from sessions alone
      scores << session_progress

      # Calculate weighted average
      return @goal.progress_percentage if scores.empty?
      scores.sum / scores.length
    end

    def gather_completion_signals
      {
        goal: {
          title: @goal.title,
          description: @goal.description,
          target_outcome: @goal.target_outcome,
          subject: @goal.subject
        },
        practice_stats: practice_statistics,
        session_summaries: recent_session_summaries,
        learning_profile: learning_profile_summary,
        milestones_completed: completed_milestones
      }
    end

    def practice_statistics
      practices = @student.practice_sessions
        .where(subject: @goal.subject)
        .where('created_at > ?', @goal.created_at)

      return {} if practices.empty?

      {
        total_sessions: practices.count,
        average_accuracy: practices.average('correct_answers::float / NULLIF(total_problems, 0)')&.round(2),
        total_problems_attempted: practices.sum(:total_problems),
        recent_accuracy_trend: calculate_accuracy_trend(practices)
      }
    end

    def calculate_accuracy_trend(practices)
      recent = practices.order(created_at: :desc).limit(5)
      older = practices.order(created_at: :desc).offset(5).limit(5)

      return 'stable' if recent.count < 3 || older.count < 3

      recent_avg = recent.average('correct_answers::float / NULLIF(total_problems, 0)') || 0
      older_avg = older.average('correct_answers::float / NULLIF(total_problems, 0)') || 0

      if recent_avg > older_avg + 0.1
        'improving'
      elsif recent_avg < older_avg - 0.1
        'declining'
      else
        'stable'
      end
    end

    def recent_session_summaries
      @student.tutoring_sessions
        .where(subject: @goal.subject)
        .where('created_at > ?', @goal.created_at)
        .order(created_at: :desc)
        .limit(5)
        .pluck(:summary)
        .compact
    end

    def learning_profile_summary
      profile = @student.learning_profiles.find_by(subject: @goal.subject)
      return {} unless profile

      {
        proficiency_level: profile.proficiency_level,
        strengths: profile.strengths,
        weaknesses: profile.weaknesses
      }
    end

    def completed_milestones
      (@goal.milestones || []).select { |m| m['completed'] }
    end

    def ai_evaluate_completion(signals)
      client = OpenAI::Client.new

      prompt = <<~PROMPT
        Evaluate if a student has completed their learning goal:

        Goal: #{signals[:goal][:title]}
        Description: #{signals[:goal][:description]}
        Target Outcome: #{signals[:goal][:target_outcome]}
        Subject: #{signals[:goal][:subject]}

        Practice Statistics:
        #{signals[:practice_stats].to_json}

        Recent Session Summaries:
        #{signals[:session_summaries].join("\n")}

        Learning Profile:
        #{signals[:learning_profile].to_json}

        Milestones Completed: #{signals[:milestones_completed].length}

        Respond in JSON:
        {
          "is_complete": true/false,
          "estimated_progress": 0-100,
          "reasoning": "brief explanation",
          "remaining_gaps": ["any remaining areas to work on"]
        }
      PROMPT

      response = client.chat(
        parameters: {
          model: 'gpt-4-turbo-preview',
          messages: [{ role: 'user', content: prompt }],
          response_format: { type: 'json_object' }
        }
      )

      JSON.parse(response.dig('choices', 0, 'message', 'content')).with_indifferent_access
    end

    def complete_goal!
      @goal.update!(
        status: :completed,
        completed_at: Time.current
      )

      # Generate next goal suggestions
      generate_next_goal_suggestions!

      # Trigger celebration and retention flow
      GoalCompletionJob.perform_later(@goal.id)
    end

    def generate_next_goal_suggestions!
      recommendations = SubjectRecommendations.get_recommendations(@goal.subject)

      suggestions = recommendations[:next_subjects].map do |subject|
        {
          subject: subject,
          reason: generate_suggestion_reason(subject),
          priority: recommendations[:priority_order].index(subject) || 99
        }
      end.sort_by { |s| s[:priority] }

      @goal.update!(suggested_next_goals: suggestions)
    end

    def generate_suggestion_reason(subject)
      # Could be enhanced with AI for personalized reasons
      "Based on your progress in #{@goal.subject}, #{subject.humanize} is a natural next step."
    end
  end
end
```

### Goal Completion Job
Create `backend/app/jobs/goal_completion_job.rb`:
```ruby
class GoalCompletionJob < ApplicationJob
  queue_as :default

  def perform(goal_id)
    goal = LearningGoal.find(goal_id)
    student = goal.student

    # Get recommendations
    recommendations = Retention::SubjectRecommendations.get_recommendations(goal.subject)

    # Send celebration notification
    send_completion_notification(student, goal, recommendations)

    # Create in-app celebration event
    create_celebration_event(student, goal)

    # Schedule follow-up nudge if no new goal created
    schedule_followup_nudge(student, goal)

    # Update analytics
    track_goal_completion(student, goal)
  end

  private

  def send_completion_notification(student, goal, recommendations)
    client = Nerdy::PlatformClient.new

    client.send_notification(
      student_id: student.external_id,
      type: 'goal_completed',
      title: "🎉 Goal Achieved: #{goal.title}!",
      message: recommendations[:message],
      data: {
        goal_id: goal.id,
        subject: goal.subject,
        next_subjects: recommendations[:next_subjects],
        cta_type: 'explore_subjects'
      }
    )
  end

  def create_celebration_event(student, goal)
    # Store event for frontend to display celebration UI
    StudentEvent.create!(
      student: student,
      event_type: 'goal_completed',
      data: {
        goal_id: goal.id,
        goal_title: goal.title,
        subject: goal.subject,
        suggested_next: goal.suggested_next_goals
      },
      expires_at: 7.days.from_now
    )
  end

  def schedule_followup_nudge(student, goal)
    # If student doesn't create a new goal within 3 days, send a nudge
    SendRetentionNudgeJob.set(wait: 3.days).perform_later(
      student.id,
      'goal_completed_followup',
      { completed_goal_id: goal.id }
    )
  end

  def track_goal_completion(student, goal)
    # Analytics tracking - integrate with your analytics service
    Rails.logger.info({
      event: 'goal_completed',
      student_id: student.id,
      goal_id: goal.id,
      subject: goal.subject,
      days_to_complete: (goal.completed_at.to_date - goal.created_at.to_date).to_i
    }.to_json)
  end
end
```

### Student Events Migration
Create `backend/db/migrate/xxx_create_student_events.rb`:
```ruby
class CreateStudentEvents < ActiveRecord::Migration[7.0]
  def change
    create_table :student_events do |t|
      t.references :student, null: false, foreign_key: true
      t.string :event_type, null: false
      t.jsonb :data, default: {}
      t.boolean :acknowledged, default: false
      t.datetime :expires_at
      t.timestamps
    end

    add_index :student_events, [:student_id, :event_type]
    add_index :student_events, [:student_id, :acknowledged]
  end
end
```

---

## Task 10: Student Engagement Nudge System

Track engagement and nudge low-activity students.

### Engagement Tracker Service
Create `backend/app/services/retention/engagement_tracker.rb`:
```ruby
module Retention
  class EngagementTracker
    # Thresholds for nudges
    MIN_SESSIONS_BY_DAY_7 = 3
    INACTIVE_DAYS_THRESHOLD = 7
    LOW_PRACTICE_THRESHOLD = 2 # practices per week

    def initialize(student:)
      @student = student
    end

    # Calculate overall engagement score (0-100)
    def engagement_score
      scores = {
        session_frequency: session_frequency_score,
        practice_activity: practice_activity_score,
        conversation_activity: conversation_activity_score,
        goal_progress: goal_progress_score,
        recency: recency_score
      }

      weights = {
        session_frequency: 0.3,
        practice_activity: 0.25,
        conversation_activity: 0.2,
        goal_progress: 0.15,
        recency: 0.1
      }

      weighted_score = scores.sum { |k, v| v * weights[k] }
      weighted_score.round
    end

    # Check if student needs a nudge
    def needs_nudge?
      return true if new_student_low_sessions?
      return true if inactive_too_long?
      return true if declining_engagement?
      return true if stalled_goal_progress?
      false
    end

    # Get appropriate nudge type
    def recommended_nudge
      return :new_student_sessions if new_student_low_sessions?
      return :inactive_reminder if inactive_too_long?
      return :declining_engagement if declining_engagement?
      return :goal_stalled if stalled_goal_progress?
      return :general_encouragement if engagement_score < 50
      nil
    end

    # Get nudge content
    def nudge_content
      case recommended_nudge
      when :new_student_sessions
        new_student_nudge_content
      when :inactive_reminder
        inactive_nudge_content
      when :declining_engagement
        declining_engagement_content
      when :goal_stalled
        goal_stalled_content
      when :general_encouragement
        encouragement_content
      end
    end

    private

    def session_frequency_score
      days_active = (@student.created_at.to_date..Date.current).count
      return 100 if days_active < 7

      sessions_count = @student.tutoring_sessions
        .where('created_at > ?', 30.days.ago)
        .count

      expected_sessions = (days_active / 7.0).ceil * 2 # ~2 sessions per week
      [sessions_count.to_f / expected_sessions * 100, 100].min.round
    end

    def practice_activity_score
      practices = @student.practice_sessions
        .where('created_at > ?', 14.days.ago)
        .count

      [practices.to_f / 7 * 100, 100].min.round # Expect ~7 in 2 weeks
    end

    def conversation_activity_score
      conversations = @student.conversations
        .where('updated_at > ?', 7.days.ago)
        .count

      messages = Message.joins(:conversation)
        .where(conversations: { student_id: @student.id })
        .where('messages.created_at > ?', 7.days.ago)
        .count

      activity = conversations * 10 + messages
      [activity.to_f / 20 * 100, 100].min.round
    end

    def goal_progress_score
      active_goals = @student.learning_goals.where(status: :active)
      return 50 if active_goals.empty? # Neutral if no goals

      avg_progress = active_goals.average(:progress_percentage) || 0
      avg_progress.round
    end

    def recency_score
      last_activity = [
        @student.tutoring_sessions.maximum(:created_at),
        @student.practice_sessions.maximum(:created_at),
        @student.conversations.maximum(:updated_at)
      ].compact.max

      return 0 unless last_activity

      days_since = (Date.current - last_activity.to_date).to_i
      [100 - (days_since * 10), 0].max
    end

    def new_student_low_sessions?
      days_since_signup = (Date.current - @student.created_at.to_date).to_i
      return false if days_since_signup > 14 # Not a new student

      if days_since_signup >= 7
        session_count = @student.tutoring_sessions
          .where('created_at > ?', @student.created_at)
          .count
        session_count < MIN_SESSIONS_BY_DAY_7
      else
        false
      end
    end

    def inactive_too_long?
      last_activity = [
        @student.tutoring_sessions.maximum(:created_at),
        @student.practice_sessions.maximum(:created_at),
        @student.conversations.maximum(:updated_at)
      ].compact.max

      return true unless last_activity
      (Date.current - last_activity.to_date).to_i >= INACTIVE_DAYS_THRESHOLD
    end

    def declining_engagement?
      # Compare last 2 weeks to previous 2 weeks
      recent = engagement_in_period(14.days.ago, Date.current)
      previous = engagement_in_period(28.days.ago, 14.days.ago)

      return false if previous == 0
      recent < previous * 0.5 # Dropped by more than 50%
    end

    def engagement_in_period(start_date, end_date)
      sessions = @student.tutoring_sessions.where(created_at: start_date..end_date).count
      practices = @student.practice_sessions.where(created_at: start_date..end_date).count
      conversations = @student.conversations.where(updated_at: start_date..end_date).count

      sessions * 3 + practices * 2 + conversations
    end

    def stalled_goal_progress?
      stalled_goals = @student.learning_goals
        .where(status: :active)
        .where('updated_at < ?', 14.days.ago)
        .where('progress_percentage < 80')

      stalled_goals.exists?
    end

    def new_student_nudge_content
      {
        type: 'new_student_sessions',
        title: "Let's keep the momentum going! 🚀",
        message: "Students who have 3+ sessions in their first week see 2x better results. Book your next session to stay on track!",
        cta: 'Book a Session',
        cta_action: 'book_session',
        priority: 'high'
      }
    end

    def inactive_nudge_content
      days = (Date.current - last_activity_date).to_i
      {
        type: 'inactive_reminder',
        title: "We miss you! 👋",
        message: "It's been #{days} days since your last activity. Your AI companion is ready to help you practice anytime!",
        cta: 'Start Practicing',
        cta_action: 'open_practice',
        priority: 'medium'
      }
    end

    def declining_engagement_content
      {
        type: 'declining_engagement',
        title: "Need a hand? 🤝",
        message: "We noticed you've been less active lately. Is there something we can help with? A quick practice session can help you get back on track.",
        cta: 'Quick Practice',
        cta_action: 'open_practice',
        priority: 'medium'
      }
    end

    def goal_stalled_content
      stalled_goal = @student.learning_goals
        .where(status: :active)
        .where('updated_at < ?', 14.days.ago)
        .first

      {
        type: 'goal_stalled',
        title: "Let's get you unstuck! 💪",
        message: "Your goal '#{stalled_goal&.title}' hasn't seen progress in a while. A tutor session could help break through!",
        cta: 'Book Tutor Session',
        cta_action: 'book_session',
        cta_data: { subject: stalled_goal&.subject },
        priority: 'high'
      }
    end

    def encouragement_content
      {
        type: 'encouragement',
        title: "You're doing great! 🌟",
        message: "Every bit of practice counts. Your AI companion has some new questions ready for you!",
        cta: 'Start Learning',
        cta_action: 'open_companion',
        priority: 'low'
      }
    end

    def last_activity_date
      [
        @student.tutoring_sessions.maximum(:created_at),
        @student.practice_sessions.maximum(:created_at),
        @student.conversations.maximum(:updated_at)
      ].compact.max&.to_date || @student.created_at.to_date
    end
  end
end
```

### Nudge Scheduler Job
Create `backend/app/jobs/check_engagement_job.rb`:
```ruby
class CheckEngagementJob < ApplicationJob
  queue_as :low

  def perform
    # Run daily to check all students
    Student.find_each do |student|
      tracker = Retention::EngagementTracker.new(student: student)

      if tracker.needs_nudge?
        nudge = tracker.nudge_content
        next unless nudge

        # Check if we've already sent this type recently
        recent_nudge = StudentNudge.where(student: student, nudge_type: nudge[:type])
          .where('created_at > ?', 3.days.ago)
          .exists?

        unless recent_nudge
          SendRetentionNudgeJob.perform_later(student.id, nudge[:type], nudge)
        end
      end
    end
  end
end
```

### Send Nudge Job
Create `backend/app/jobs/send_retention_nudge_job.rb`:
```ruby
class SendRetentionNudgeJob < ApplicationJob
  queue_as :default

  def perform(student_id, nudge_type, nudge_data = {})
    student = Student.find(student_id)
    client = Nerdy::PlatformClient.new

    # Get nudge content
    content = nudge_data.presence || generate_nudge_content(student, nudge_type)
    return unless content

    # Record the nudge
    StudentNudge.create!(
      student: student,
      nudge_type: nudge_type,
      content: content,
      sent_at: Time.current
    )

    # Send via Nerdy platform
    client.send_notification(
      student_id: student.external_id,
      type: nudge_type,
      title: content[:title],
      message: content[:message],
      data: {
        cta: content[:cta],
        cta_action: content[:cta_action],
        cta_data: content[:cta_data]
      }
    )

    # Also create in-app notification
    StudentEvent.create!(
      student: student,
      event_type: 'nudge',
      data: content,
      expires_at: 7.days.from_now
    )
  end

  private

  def generate_nudge_content(student, nudge_type)
    tracker = Retention::EngagementTracker.new(student: student)
    tracker.nudge_content
  end
end
```

### Student Nudges Migration
Create `backend/db/migrate/xxx_create_student_nudges.rb`:
```ruby
class CreateStudentNudges < ActiveRecord::Migration[7.0]
  def change
    create_table :student_nudges do |t|
      t.references :student, null: false, foreign_key: true
      t.string :nudge_type, null: false
      t.jsonb :content, default: {}
      t.datetime :sent_at
      t.datetime :opened_at
      t.datetime :acted_at
      t.string :action_taken
      t.timestamps
    end

    add_index :student_nudges, [:student_id, :nudge_type, :created_at]
  end
end
```

---

## Task 11: Human Tutor Handoff System

Detect when AI can't help and smoothly hand off to human tutors.

### Escalation Detector Service
Create `backend/app/services/ai/escalation_detector.rb`:
```ruby
module AI
  class EscalationDetector
    ESCALATION_TRIGGERS = {
      repeated_confusion: 3,      # Same question asked 3+ times
      frustration_signals: 2,     # 2+ frustration indicators
      complex_topic_threshold: 8, # Difficulty level 8+
      low_confidence_responses: 3 # AI unsure 3+ times
    }.freeze

    FRUSTRATION_PATTERNS = [
      /i don't (understand|get it)/i,
      /this (doesn't|does not) make sense/i,
      /i('m| am) (so )?(confused|lost|frustrated)/i,
      /can you explain (again|differently)/i,
      /i give up/i,
      /this is (too )?hard/i,
      /help me/i,
      /\?{2,}/, # Multiple question marks
      /!{2,}/   # Multiple exclamation marks (frustration)
    ].freeze

    def initialize(conversation:)
      @conversation = conversation
      @student = conversation.student
      @messages = conversation.messages.order(:created_at)
    end

    def should_escalate?
      return true if repeated_confusion?
      return true if frustration_detected?
      return true if topic_too_complex?
      return true if ai_struggling?
      false
    end

    def escalation_reason
      reasons = []
      reasons << 'repeated_confusion' if repeated_confusion?
      reasons << 'student_frustration' if frustration_detected?
      reasons << 'complex_topic' if topic_too_complex?
      reasons << 'ai_limitations' if ai_struggling?
      reasons
    end

    def generate_escalation_context
      {
        conversation_id: @conversation.id,
        student_id: @student.id,
        subject: @conversation.subject,
        reasons: escalation_reason,
        conversation_summary: summarize_conversation,
        student_struggles: identify_struggles,
        recommended_session_focus: recommend_focus_areas,
        urgency: calculate_urgency
      }
    end

    private

    def repeated_confusion?
      user_messages = @messages.where(role: 'user').pluck(:content)
      return false if user_messages.length < 3

      # Check for similar questions
      recent_messages = user_messages.last(5)
      similar_count = count_similar_messages(recent_messages)
      similar_count >= ESCALATION_TRIGGERS[:repeated_confusion]
    end

    def count_similar_messages(messages)
      return 0 if messages.length < 2

      similarities = messages.combination(2).count do |m1, m2|
        similar_content?(m1, m2)
      end

      # Convert combinations to approximate repeat count
      (similarities / 2.0).ceil + 1
    end

    def similar_content?(text1, text2)
      # Simple similarity check - could be enhanced with embeddings
      words1 = text1.downcase.split(/\W+/).to_set
      words2 = text2.downcase.split(/\W+/).to_set

      intersection = words1 & words2
      union = words1 | words2

      return false if union.empty?
      intersection.size.to_f / union.size > 0.5
    end

    def frustration_detected?
      recent_user_messages = @messages.where(role: 'user').last(5)

      frustration_count = recent_user_messages.count do |msg|
        FRUSTRATION_PATTERNS.any? { |pattern| msg.content.match?(pattern) }
      end

      frustration_count >= ESCALATION_TRIGGERS[:frustration_signals]
    end

    def topic_too_complex?
      # Check if we're discussing advanced topics
      profile = @student.learning_profiles.find_by(subject: @conversation.subject)
      return false unless profile

      # If topic difficulty exceeds student level significantly
      current_topic_difficulty = estimate_topic_difficulty
      student_level = profile.proficiency_level

      current_topic_difficulty - student_level >= 3
    end

    def estimate_topic_difficulty
      # Analyze recent messages to estimate difficulty
      recent_content = @messages.last(5).pluck(:content).join(' ')

      advanced_indicators = [
        /theorem|proof|derive|integral|differential/i,
        /synthesis|analysis|evaluate|critique/i,
        /advanced|complex|challenging/i
      ]

      indicator_count = advanced_indicators.count { |i| recent_content.match?(i) }

      base_difficulty = 5
      base_difficulty + (indicator_count * 2)
    end

    def ai_struggling?
      # Check if AI has been giving uncertain responses
      recent_ai_messages = @messages.where(role: 'assistant').last(5)

      uncertain_patterns = [
        /i('m| am) not (entirely )?sure/i,
        /this (might|may) be/i,
        /i think/i,
        /it's possible that/i,
        /you (should|might want to) (ask|consult|check with)/i
      ]

      uncertain_count = recent_ai_messages.count do |msg|
        uncertain_patterns.any? { |pattern| msg.content.match?(pattern) }
      end

      uncertain_count >= ESCALATION_TRIGGERS[:low_confidence_responses]
    end

    def summarize_conversation
      messages_text = @messages.last(10).map do |m|
        "#{m.role}: #{m.content.truncate(200)}"
      end.join("\n")

      client = OpenAI::Client.new
      response = client.chat(
        parameters: {
          model: 'gpt-4-turbo-preview',
          messages: [{
            role: 'user',
            content: "Summarize this tutoring conversation in 2-3 sentences, focusing on what the student is trying to learn and where they're struggling:\n\n#{messages_text}"
          }],
          max_tokens: 150
        }
      )

      response.dig('choices', 0, 'message', 'content')
    end

    def identify_struggles
      user_questions = @messages.where(role: 'user').pluck(:content)

      # Extract topics from questions
      topics = user_questions.flat_map do |q|
        extract_topics(q)
      end.tally.sort_by { |_, count| -count }.first(5).map(&:first)

      topics
    end

    def extract_topics(text)
      # Simple topic extraction - could be enhanced with NER
      text.downcase.scan(/\b(how|what|why|when|where|explain|help with)\s+(.+?)[\?\.]/)
        .map { |_, topic| topic.strip }
    end

    def recommend_focus_areas
      struggles = identify_struggles
      profile = @student.learning_profiles.find_by(subject: @conversation.subject)

      areas = []
      areas += struggles.first(3)
      areas += (profile&.weaknesses || []).first(2)
      areas.uniq.first(5)
    end

    def calculate_urgency
      if frustration_detected? && repeated_confusion?
        'high'
      elsif frustration_detected? || repeated_confusion?
        'medium'
      else
        'low'
      end
    end
  end
end
```

### Handoff Service
Create `backend/app/services/retention/tutor_handoff_service.rb`:
```ruby
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
```

### Tutor Handoff Migration
Create `backend/db/migrate/xxx_create_tutor_handoffs.rb`:
```ruby
class CreateTutorHandoffs < ActiveRecord::Migration[7.0]
  def change
    create_table :tutor_handoffs do |t|
      t.references :student, null: false, foreign_key: true
      t.references :conversation, foreign_key: true
      t.string :tutor_external_id
      t.string :subject
      t.string :escalation_reasons, array: true, default: []
      t.text :context_summary
      t.string :focus_areas, array: true, default: []
      t.string :booking_external_id
      t.datetime :scheduled_at
      t.string :status, default: 'pending' # pending, confirmed, completed, cancelled
      t.timestamps
    end

    add_index :tutor_handoffs, [:student_id, :status]
  end
end
```

---

## Task 16: Tutor Preparation Brief Generator

Generate AI-powered preparation summaries for tutors.

### Tutor Brief Service
Create `backend/app/services/ai/tutor_brief_service.rb`:
```ruby
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
```

### Tutor Brief Migration
Create `backend/db/migrate/xxx_create_tutor_briefs.rb`:
```ruby
class CreateTutorBriefs < ActiveRecord::Migration[7.0]
  def change
    create_table :tutor_briefs do |t|
      t.references :student, null: false, foreign_key: true
      t.references :tutor, null: false, foreign_key: true
      t.string :subject
      t.datetime :session_datetime
      t.text :content
      t.jsonb :data_snapshot, default: {}
      t.boolean :viewed, default: false
      t.datetime :viewed_at
      t.timestamps
    end

    add_index :tutor_briefs, [:tutor_id, :session_datetime]
  end
end
```

### Tutor Brief Controller
Create `backend/app/controllers/api/v1/tutor_briefs_controller.rb`:
```ruby
module Api
  module V1
    class TutorBriefsController < ApplicationController
      skip_before_action :authenticate_request
      before_action :authenticate_tutor

      # GET /api/v1/tutor_briefs
      def index
        briefs = TutorBrief
          .where(tutor: @current_tutor)
          .where('session_datetime > ?', Time.current)
          .order(session_datetime: :asc)

        render json: briefs.map { |b| TutorBriefSerializer.new(b) }
      end

      # GET /api/v1/tutor_briefs/:id
      def show
        brief = TutorBrief.find(params[:id])

        # Mark as viewed
        brief.update!(viewed: true, viewed_at: Time.current) unless brief.viewed?

        render json: TutorBriefSerializer.new(brief, full: true)
      end

      # POST /api/v1/tutor_briefs/generate
      def generate
        student = Student.find(params[:student_id])

        service = AI::TutorBriefService.new(
          student: student,
          tutor: @current_tutor,
          subject: params[:subject],
          session_datetime: Time.parse(params[:session_datetime])
        )

        brief = service.generate_brief

        render json: { content: brief }, status: :created
      end

      private

      def authenticate_tutor
        token = extract_token
        payload = JwtService.decode(token)

        if payload && payload[:tutor_id]
          @current_tutor = Tutor.find_by(id: payload[:tutor_id])
        end

        render json: { error: 'Unauthorized' }, status: :unauthorized unless @current_tutor
      end

      def extract_token
        header = request.headers['Authorization']
        header&.split(' ')&.last
      end
    end
  end
end
```

---

## API Routes Update

Add to `backend/config/routes.rb`:
```ruby
namespace :api do
  namespace :v1 do
    # ... existing routes ...

    # Engagement & Retention
    resources :student_events, only: [:index] do
      collection do
        post :acknowledge
      end
    end

    # Tutor Handoffs
    resources :handoffs, only: [:create, :show] do
      member do
        post :book
      end
    end

    # Tutor Briefs (tutor-facing)
    resources :tutor_briefs, only: [:index, :show] do
      collection do
        post :generate
      end
    end

    # Goals with suggestions
    resources :learning_goals do
      member do
        get :suggestions
        post :evaluate_completion
      end
    end
  end
end
```

---

## Scheduled Jobs (Cron)

Add to `config/schedule.rb` (using whenever gem) or configure in your job scheduler:

```ruby
# Check engagement daily at 9 AM
every 1.day, at: '9:00 am' do
  runner "CheckEngagementJob.perform_later"
end

# Sync sessions every 6 hours
every 6.hours do
  runner "Student.find_each { |s| SyncStudentSessionsJob.perform_later(s.id) }"
end

# Generate tutor briefs 24 hours before sessions
every 1.hour do
  runner "GenerateUpcomingBriefsJob.perform_later"
end
```

---

## Models Summary

Create these models in `backend/app/models/`:

```ruby
# student_event.rb
class StudentEvent < ApplicationRecord
  belongs_to :student
  scope :unacknowledged, -> { where(acknowledged: false) }
  scope :active, -> { where('expires_at IS NULL OR expires_at > ?', Time.current) }
end

# student_nudge.rb
class StudentNudge < ApplicationRecord
  belongs_to :student
  scope :recent, -> { where('created_at > ?', 7.days.ago) }
end

# tutor_handoff.rb
class TutorHandoff < ApplicationRecord
  belongs_to :student
  belongs_to :conversation, optional: true
  enum status: { pending: 'pending', confirmed: 'confirmed', completed: 'completed', cancelled: 'cancelled' }
end

# tutor_brief.rb
class TutorBrief < ApplicationRecord
  belongs_to :student
  belongs_to :tutor
  scope :upcoming, -> { where('session_datetime > ?', Time.current) }
  scope :unviewed, -> { where(viewed: false) }
end
```

---

## Environment Variables

Add to `backend/.env`:
```
NERDY_PLATFORM_URL=https://api.nerdy.com
NERDY_API_KEY=your-nerdy-api-key
```

---

## Validation Checklist

- [ ] Session sync imports from Nerdy platform
- [ ] Transcripts are processed and stored in vector DB
- [ ] Goal completion triggers suggestions
- [ ] Engagement tracker correctly identifies low-engagement students
- [ ] Nudges are sent (not duplicated within 3 days)
- [ ] Escalation detector identifies frustration patterns
- [ ] Handoff suggestions include available tutors
- [ ] Tutor briefs are generated with comprehensive context
- [ ] All migrations run successfully

Execute this entire implementation for the retention and engagement systems.
