class CreatePracticeSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :practice_sessions do |t|
      t.references :student, null: false, foreign_key: true
      t.references :learning_goal, foreign_key: true
      t.string :subject, null: false
      t.string :session_type  # quiz, flashcards, worksheet
      t.integer :total_problems, default: 0
      t.integer :correct_answers, default: 0
      t.integer :time_spent_seconds, default: 0
      t.jsonb :struggled_topics, default: []
      t.datetime :completed_at
      t.timestamps
    end
  end
end

