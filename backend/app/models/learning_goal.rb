class LearningGoal < ApplicationRecord
  belongs_to :student
  has_many :practice_sessions

  validates :title, presence: true
  validates :subject, presence: true

  enum :status, { pending: 0, active: 1, completed: 2, paused: 3 }
end

