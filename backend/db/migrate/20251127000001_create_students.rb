class CreateStudents < ActiveRecord::Migration[8.1]
  def change
    create_table :students do |t|
      t.string :external_id, null: false, index: { unique: true }  # Nerdy platform ID
      t.string :email, null: false
      t.string :first_name
      t.string :last_name
      t.jsonb :preferences, default: {}
      t.jsonb :learning_style, default: {}
      t.timestamps
    end
  end
end

