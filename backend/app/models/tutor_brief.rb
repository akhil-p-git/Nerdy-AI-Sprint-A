class TutorBrief < ApplicationRecord
  belongs_to :student
  belongs_to :tutor
  scope :upcoming, -> { where('session_datetime > ?', Time.current) }
  scope :unviewed, -> { where(viewed: false) }
end


