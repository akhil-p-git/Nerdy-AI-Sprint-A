class CreateLearningGoals < ActiveRecord::Migration[8.1]
  def change
    create_table :learning_goals do |t|
      t.references :student, null: false, foreign_key: true
      t.string :subject, null: false
      t.string :title, null: false
      t.text :description
      t.string :target_outcome
      t.date :target_date
      t.integer :status, default: 0  # enum: pending, active, completed, paused
      t.integer :progress_percentage, default: 0
      t.jsonb :milestones, default: []
      t.jsonb :suggested_next_goals, default: []
      t.datetime :completed_at
      t.timestamps
    end
    add_index :learning_goals, [:student_id, :status]
  end
end

