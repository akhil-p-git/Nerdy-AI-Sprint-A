class CreateStudentEvents < ActiveRecord::Migration[8.1]
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


