class CreateTutors < ActiveRecord::Migration[8.1]
  def change
    create_table :tutors do |t|
      t.string :external_id, null: false, index: { unique: true }
      t.string :email, null: false
      t.string :first_name
      t.string :last_name
      t.string :subjects, array: true, default: []
      t.timestamps
    end
  end
end

