class CreateAiUsageLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :ai_usage_logs do |t|
      t.references :student, foreign_key: true
      t.string :model, null: false
      t.string :operation
      t.integer :input_tokens, default: 0
      t.integer :output_tokens, default: 0
      t.decimal :cost_usd, precision: 10, scale: 6, default: 0
      t.timestamps
    end

    add_index :ai_usage_logs, :created_at
    add_index :ai_usage_logs, [:student_id, :created_at]
  end
end


