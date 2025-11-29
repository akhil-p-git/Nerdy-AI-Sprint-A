class CreateTutorBriefs < ActiveRecord::Migration[8.1]
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


