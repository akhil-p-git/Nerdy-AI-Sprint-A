class CreateParents < ActiveRecord::Migration[8.1]
  def change
    create_table :parents do |t|
      t.string :external_id, null: false, index: { unique: true }
      t.string :email, null: false
      t.string :first_name
      t.string :last_name
      t.jsonb :notification_preferences, default: {}
      t.timestamps
    end

    create_table :parent_students do |t|
      t.references :parent, null: false, foreign_key: true
      t.references :student, null: false, foreign_key: true
      t.string :relationship, default: 'parent'
      t.timestamps
    end

    add_index :parent_students, [:parent_id, :student_id], unique: true
  end
end


