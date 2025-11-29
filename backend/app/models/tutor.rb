class Tutor < ApplicationRecord
  has_many :tutoring_sessions

  validates :email, presence: true
  validates :external_id, presence: true, uniqueness: true
end

