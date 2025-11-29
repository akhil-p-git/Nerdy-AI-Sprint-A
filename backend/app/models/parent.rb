class Parent < ApplicationRecord
  has_many :parent_students
  has_many :students, through: :parent_students

  validates :external_id, presence: true, uniqueness: true
  validates :email, presence: true
end


