class CreateLearningProfiles < ActiveRecord::Migration[8.1]
  def change
    create_table :learning_profiles do |t|
      t.references :student, null: false, foreign_key: true
      t.string :subject, null: false
      t.integer :proficiency_level, default: 1  # 1-10
      t.jsonb :strengths, default: []
      t.jsonb :weaknesses, default: []
      t.jsonb :knowledge_gaps, default: []
      t.datetime :last_assessed_at
      t.timestamps

      t.index [:student_id, :subject], unique: true
    end
  end
end

