class CreateTutorHandoffs < ActiveRecord::Migration[8.1]
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


