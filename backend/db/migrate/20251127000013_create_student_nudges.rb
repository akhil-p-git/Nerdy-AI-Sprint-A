class CreateStudentNudges < ActiveRecord::Migration[8.1]
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


