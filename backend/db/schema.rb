# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2025_11_27_000019) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "vector"

  create_table "ai_usage_logs", force: :cascade do |t|
    t.decimal "cost_usd", precision: 10, scale: 6, default: "0.0"
    t.datetime "created_at", null: false
    t.integer "input_tokens", default: 0
    t.string "model", null: false
    t.string "operation"
    t.integer "output_tokens", default: 0
    t.bigint "student_id"
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_ai_usage_logs_on_created_at"
    t.index ["student_id", "created_at"], name: "index_ai_usage_logs_on_student_id_and_created_at"
    t.index ["student_id"], name: "index_ai_usage_logs_on_student_id"
  end

  create_table "analytics_events", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "event_name", null: false
    t.datetime "occurred_at", null: false
    t.jsonb "properties", default: {}
    t.bigint "student_id"
    t.datetime "updated_at", null: false
    t.index ["event_name"], name: "index_analytics_events_on_event_name"
    t.index ["occurred_at"], name: "index_analytics_events_on_occurred_at"
    t.index ["student_id", "event_name", "occurred_at"], name: "idx_on_student_id_event_name_occurred_at_b67959cc71"
    t.index ["student_id"], name: "index_analytics_events_on_student_id"
  end

  create_table "conversations", force: :cascade do |t|
    t.jsonb "context", default: {}
    t.datetime "created_at", null: false
    t.string "status", default: "active"
    t.bigint "student_id", null: false
    t.string "subject"
    t.datetime "updated_at", null: false
    t.index ["student_id"], name: "index_conversations_on_student_id"
  end

# Could not dump table "knowledge_nodes" because of following StandardError
#   Unknown type 'vector(1536)' for column 'embedding'


  create_table "learning_goals", force: :cascade do |t|
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.text "description"
    t.jsonb "milestones", default: []
    t.integer "progress_percentage", default: 0
    t.integer "status", default: 0
    t.bigint "student_id", null: false
    t.string "subject", null: false
    t.jsonb "suggested_next_goals", default: []
    t.date "target_date"
    t.string "target_outcome"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["student_id", "status"], name: "index_learning_goals_on_student_id_and_status"
    t.index ["student_id"], name: "index_learning_goals_on_student_id"
  end

  create_table "learning_profiles", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.jsonb "knowledge_gaps", default: []
    t.datetime "last_assessed_at"
    t.integer "proficiency_level", default: 1
    t.jsonb "strengths", default: []
    t.bigint "student_id", null: false
    t.string "subject", null: false
    t.datetime "updated_at", null: false
    t.jsonb "weaknesses", default: []
    t.index ["student_id", "subject"], name: "index_learning_profiles_on_student_id_and_subject", unique: true
    t.index ["student_id"], name: "index_learning_profiles_on_student_id"
  end

  create_table "messages", force: :cascade do |t|
    t.text "content", null: false
    t.bigint "conversation_id", null: false
    t.datetime "created_at", null: false
    t.jsonb "metadata", default: {}
    t.string "role", null: false
    t.datetime "updated_at", null: false
    t.index ["conversation_id", "created_at"], name: "index_messages_on_conversation_id_and_created_at"
    t.index ["conversation_id"], name: "index_messages_on_conversation_id"
  end

  create_table "parent_students", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "parent_id", null: false
    t.string "relationship", default: "parent"
    t.bigint "student_id", null: false
    t.datetime "updated_at", null: false
    t.index ["parent_id", "student_id"], name: "index_parent_students_on_parent_id_and_student_id", unique: true
    t.index ["parent_id"], name: "index_parent_students_on_parent_id"
    t.index ["student_id"], name: "index_parent_students_on_student_id"
  end

  create_table "parents", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "external_id", null: false
    t.string "first_name"
    t.string "last_name"
    t.jsonb "notification_preferences", default: {}
    t.datetime "updated_at", null: false
    t.index ["external_id"], name: "index_parents_on_external_id", unique: true
  end

  create_table "practice_problems", force: :cascade do |t|
    t.text "correct_answer"
    t.datetime "created_at", null: false
    t.integer "difficulty_level", default: 5
    t.text "explanation"
    t.boolean "is_correct"
    t.jsonb "options", default: []
    t.bigint "practice_session_id", null: false
    t.string "problem_type"
    t.text "question", null: false
    t.text "student_answer"
    t.integer "time_spent_seconds"
    t.string "topic"
    t.datetime "updated_at", null: false
    t.index ["practice_session_id"], name: "index_practice_problems_on_practice_session_id"
  end

  create_table "practice_sessions", force: :cascade do |t|
    t.datetime "completed_at"
    t.integer "correct_answers", default: 0
    t.datetime "created_at", null: false
    t.bigint "learning_goal_id"
    t.string "session_type"
    t.jsonb "struggled_topics", default: []
    t.bigint "student_id", null: false
    t.string "subject", null: false
    t.integer "time_spent_seconds", default: 0
    t.integer "total_problems", default: 0
    t.datetime "updated_at", null: false
    t.index ["learning_goal_id"], name: "index_practice_sessions_on_learning_goal_id"
    t.index ["student_id"], name: "index_practice_sessions_on_student_id"
  end

  create_table "security_audit_logs", force: :cascade do |t|
    t.string "audit_type", null: false
    t.datetime "created_at", null: false
    t.jsonb "results", default: {}
    t.string "status"
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_security_audit_logs_on_created_at"
    t.index ["status"], name: "index_security_audit_logs_on_status"
  end

  create_table "student_events", force: :cascade do |t|
    t.boolean "acknowledged", default: false
    t.datetime "created_at", null: false
    t.jsonb "data", default: {}
    t.string "event_type", null: false
    t.datetime "expires_at"
    t.bigint "student_id", null: false
    t.datetime "updated_at", null: false
    t.index ["student_id", "acknowledged"], name: "index_student_events_on_student_id_and_acknowledged"
    t.index ["student_id", "event_type"], name: "index_student_events_on_student_id_and_event_type"
    t.index ["student_id"], name: "index_student_events_on_student_id"
  end

  create_table "student_nudges", force: :cascade do |t|
    t.datetime "acted_at"
    t.string "action_taken"
    t.jsonb "content", default: {}
    t.datetime "created_at", null: false
    t.string "nudge_type", null: false
    t.datetime "opened_at"
    t.datetime "sent_at"
    t.bigint "student_id", null: false
    t.datetime "updated_at", null: false
    t.index ["student_id", "nudge_type", "created_at"], name: "idx_on_student_id_nudge_type_created_at_dea582d20a"
    t.index ["student_id"], name: "index_student_nudges_on_student_id"
  end

  create_table "students", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "external_id", null: false
    t.string "first_name"
    t.string "last_name"
    t.jsonb "learning_style", default: {}
    t.jsonb "preferences", default: {}
    t.datetime "updated_at", null: false
    t.index ["external_id"], name: "index_students_on_external_id", unique: true
  end

  create_table "tutor_briefs", force: :cascade do |t|
    t.text "content"
    t.datetime "created_at", null: false
    t.jsonb "data_snapshot", default: {}
    t.datetime "session_datetime"
    t.bigint "student_id", null: false
    t.string "subject"
    t.bigint "tutor_id", null: false
    t.datetime "updated_at", null: false
    t.boolean "viewed", default: false
    t.datetime "viewed_at"
    t.index ["student_id"], name: "index_tutor_briefs_on_student_id"
    t.index ["tutor_id", "session_datetime"], name: "index_tutor_briefs_on_tutor_id_and_session_datetime"
    t.index ["tutor_id"], name: "index_tutor_briefs_on_tutor_id"
  end

  create_table "tutor_handoffs", force: :cascade do |t|
    t.string "booking_external_id"
    t.text "context_summary"
    t.bigint "conversation_id"
    t.datetime "created_at", null: false
    t.string "escalation_reasons", default: [], array: true
    t.string "focus_areas", default: [], array: true
    t.datetime "scheduled_at"
    t.string "status", default: "pending"
    t.bigint "student_id", null: false
    t.string "subject"
    t.string "tutor_external_id"
    t.datetime "updated_at", null: false
    t.index ["conversation_id"], name: "index_tutor_handoffs_on_conversation_id"
    t.index ["student_id", "status"], name: "index_tutor_handoffs_on_student_id_and_status"
    t.index ["student_id"], name: "index_tutor_handoffs_on_student_id"
  end

  create_table "tutoring_sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "ended_at"
    t.string "external_session_id"
    t.jsonb "key_concepts", default: []
    t.datetime "started_at"
    t.bigint "student_id", null: false
    t.string "subject"
    t.text "summary"
    t.jsonb "topics_covered", default: []
    t.text "transcript_url"
    t.bigint "tutor_id"
    t.datetime "updated_at", null: false
    t.index ["external_session_id"], name: "index_tutoring_sessions_on_external_session_id"
    t.index ["student_id"], name: "index_tutoring_sessions_on_student_id"
    t.index ["tutor_id"], name: "index_tutoring_sessions_on_tutor_id"
  end

  create_table "tutors", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "external_id", null: false
    t.string "first_name"
    t.string "last_name"
    t.string "subjects", default: [], array: true
    t.datetime "updated_at", null: false
    t.index ["external_id"], name: "index_tutors_on_external_id", unique: true
  end

  add_foreign_key "ai_usage_logs", "students"
  add_foreign_key "analytics_events", "students"
  add_foreign_key "conversations", "students"
  add_foreign_key "knowledge_nodes", "students"
  add_foreign_key "learning_goals", "students"
  add_foreign_key "learning_profiles", "students"
  add_foreign_key "messages", "conversations"
  add_foreign_key "parent_students", "parents"
  add_foreign_key "parent_students", "students"
  add_foreign_key "practice_problems", "practice_sessions"
  add_foreign_key "practice_sessions", "learning_goals"
  add_foreign_key "practice_sessions", "students"
  add_foreign_key "student_events", "students"
  add_foreign_key "student_nudges", "students"
  add_foreign_key "tutor_briefs", "students"
  add_foreign_key "tutor_briefs", "tutors"
  add_foreign_key "tutor_handoffs", "conversations"
  add_foreign_key "tutor_handoffs", "students"
  add_foreign_key "tutoring_sessions", "students"
  add_foreign_key "tutoring_sessions", "tutors"
end
