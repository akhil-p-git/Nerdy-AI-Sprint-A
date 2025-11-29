class CreateConversations < ActiveRecord::Migration[8.1]
  def change
    create_table :conversations do |t|
      t.references :student, null: false, foreign_key: true
      t.string :subject
      t.string :status, default: 'active'  # active, archived
      t.jsonb :context, default: {}
      t.timestamps
    end
  end
end

