class LearningProfile < ApplicationRecord
  belongs_to :student

  validates :subject, presence: true
  validates :subject, uniqueness: { scope: :student_id }
end

