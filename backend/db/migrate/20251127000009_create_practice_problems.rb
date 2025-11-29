class CreatePracticeProblems < ActiveRecord::Migration[8.1]
  def change
    create_table :practice_problems do |t|
      t.references :practice_session, null: false, foreign_key: true
      t.string :problem_type  # multiple_choice, free_response, flashcard
      t.text :question, null: false
      t.text :correct_answer
      t.jsonb :options, default: []  # for multiple choice
      t.text :student_answer
      t.boolean :is_correct
      t.integer :difficulty_level, default: 5  # 1-10
      t.string :topic
      t.text :explanation
      t.integer :time_spent_seconds
      t.timestamps
    end
  end
end

