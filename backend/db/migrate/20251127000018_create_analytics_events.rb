class CreateAnalyticsEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :analytics_events do |t|
      t.string :event_name, null: false
      t.references :student, foreign_key: true
      t.jsonb :properties, default: {}
      t.datetime :occurred_at, null: false
      t.timestamps
    end

    add_index :analytics_events, :event_name
    add_index :analytics_events, :occurred_at
    add_index :analytics_events, [:student_id, :event_name, :occurred_at]
  end
end


