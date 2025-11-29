class CreateTutoringSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :tutoring_sessions do |t|
      t.references :student, null: false, foreign_key: true
      t.references :tutor, foreign_key: true
      t.string :external_session_id, index: true  # Nerdy platform session ID
      t.string :subject
      t.text :summary
      t.jsonb :topics_covered, default: []
      t.jsonb :key_concepts, default: []
      t.text :transcript_url
      t.datetime :started_at
      t.datetime :ended_at
      t.timestamps
    end
  end
end

