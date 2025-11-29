class StudentNudge < ApplicationRecord
  belongs_to :student
  scope :recent, -> { where('created_at > ?', 7.days.ago) }
end


